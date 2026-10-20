import {SERVICE,MODEL,encode,Framer,capabilities,requireSuccess,pairs,noise,featureStates,
  gestures,customPresets,connectedDevices,firmware} from './protocol.js';
const delay = ms => new Promise(resolve=>setTimeout(resolve,ms));
export class BudsSession extends EventTarget {
  constructor(record=()=>{}) {
    super();this.record=record;this.port=null;this.reader=null;this.pending=new Map();
    this.sequence=1;this.queue=Promise.resolve();this.generation=0;this.connected=false;
    this.state={};this.events=0;this.closing=null;
  }
  emit(type,detail) {this.dispatchEvent(new CustomEvent(type,{detail}));}
  async choose() {
    const granted=await navigator.serial.getPorts();
    const matches=granted.filter(port=>port.getInfo().bluetoothServiceClassId?.toLowerCase()===SERVICE);
    if(matches.length===1)return matches[0];
    return navigator.serial.requestPort({allowedBluetoothServiceClassIds:[SERVICE],filters:[{bluetoothServiceClassId:SERVICE}]});
  }
  async connect(port) {
    if(this.connected||this.reader)throw Error('Already connected');
    if(this.closing)await this.closing;
    this.port=port;await port.open({baudRate:9600});
    this.connected=true;this.state={};this.events=0;const generation=++this.generation;
    this.reader=port.readable.getReader();
    const framer=new Framer(frame=>this.receive(frame),reason=>this.record('invalid_frame',{reason}));
    const reader=this.reader;
    this.readTask=(async()=>{
      try {
        while(this.connected&&this.generation===generation){
          const {value,done}=await reader.read();if(done)break;framer.push(value);
        }
        if(this.connected&&this.generation===generation)this.close('Device disconnected');
      } catch(error) {if(this.connected&&this.generation===generation)this.close(error.message);}
    })();
    this.emit('connection',{connected:true});this.record('connected',{info:port.getInfo()});
    await delay(300);
    try {
      this.caps=capabilities(await this.query(0x0100));
      const identity=await this.query(0x0103);requireSuccess(identity,4);
      if(identity.length!==4)throw Error('Invalid model reply');
      const model=(identity[1]|identity[2]<<8|identity[3]<<16).toString(16).padStart(6,'0');
      if(model!==MODEL)throw Error('This version supports OnePlus Buds 4 only');
      this.setState({model});await this.refresh();
      try{await this.subscribe();}
      catch(error){this.record('subscription_error',{message:error.message});this.emit('fieldError',{field:'subscriptions',message:error.message});}
    } catch(error) {await this.close(error.message);throw error;}
  }
  async close(reason='Disconnected') {
    if(this.closing)return this.closing;
    this.connected=false;++this.generation;
    for(const item of this.pending.values())item.reject(Error(reason));this.pending.clear();
    const reader=this.reader;this.reader=null;
    this.emit('connection',{connected:false,reason});
    this.closing=(async()=>{
      try{await reader?.cancel();}catch{}
      try{reader?.releaseLock();}catch{}
      try{await this.port?.close();}catch{}
      this.record('disconnected',{reason});this.queue=Promise.resolve();
    })();
    try{await this.closing;}finally{this.closing=null;}
  }
  query(command,payload=[]) {
    const generation=this.generation;
    const work=this.queue.catch(()=>{}).then(async()=>{
      if(!this.connected||generation!==this.generation)throw Error('Session changed');
      const sequence=this.sequence;this.sequence=sequence===254?1:sequence+1;
      const bytes=encode(command,sequence,payload),key=(command|0x8000)+':'+sequence;
      let timer;
      const answer=new Promise((resolve,reject)=>{
        this.pending.set(key,{resolve,reject});
        timer=setTimeout(()=>reject(Error(`No reply for ${command.toString(16)}`)),3500);
      });answer.catch(()=>{});
      try{
        const writer=this.port.writable.getWriter();
        try{await writer.write(bytes);}finally{writer.releaseLock();}
        this.record('request',{command:command.toString(16),sequence,payload});
        return await answer;
      } finally {clearTimeout(timer);this.pending.delete(key);await delay(150);}
    });
    this.queue=work;return work;
  }
  receive(frame) {
    const key=frame.command+':'+frame.sequence,item=this.pending.get(key);
    if(item){
      this.pending.delete(key);
      // Paired-device replies contain other hosts' identifiers; retain only their size.
      this.record('response',frame.command===0x8112
        ? {command:'8112',sequence:frame.sequence,payloadLength:frame.payload.length,identifiersOmitted:true}
        : {command:frame.command.toString(16),sequence:frame.sequence,payload:frame.payload,
          hex:frame.bytes.map(x=>x.toString(16).padStart(2,'0')).join(' ')});
      item.resolve(frame.payload);return;
    }
    const p=frame.payload;
    if(frame.command===0x0204&&this.state.model===MODEL){
      let patch;
      if(p[0]===1){const battery=pairs(p.slice(1),{battery:true});if(battery)patch={battery:{...this.state.battery,...battery}};}
      if(p[0]===2){const wearing=pairs(p.slice(1));if(wearing)patch={wearing:{...this.state.wearing,...wearing}};}
      if(p[0]===3&&p[1]===1&&p[2]===1){try{patch={noise:noise([0,...p.slice(1)])};}catch{}}
      if(p[0]===5&&p.length===2){patch={features:{...this.state.features,6:p[1]}};}
      if(patch){
        this.events++;this.setState(patch);this.emit('live',{code:p[0],events:this.events});
        this.record('live_event',{code:p[0],payload:p,events:this.events});return;
      }
    }
    if(frame.command===0x0504&&p.length===1&&this.state.model===MODEL){this.setState({eq:p[0]});this.events++;this.emit('live',{code:'eq',events:this.events});}
    else this.record('unhandled_frame',{command:frame.command.toString(16),sequence:frame.sequence,payloadLength:p.length});
  }
  setState(patch) {Object.assign(this.state,patch,{updatedAt:new Date().toISOString()});this.emit('state',this.state);}
  async read(command,payload,field,decoder){
    if(!this.caps.supports(command)){this.record('query_skipped',{command:command.toString(16),reason:'not offered'});return;}
    try{const raw=await this.query(command,payload);const value=decoder(raw);if(value==null)throw Error('Unrecognized reply');if(this.state.errors)delete this.state.errors[field];this.setState({[field]:value});}
    catch(error){this.state.errors??={};this.state.errors[field]=error.message;this.record('query_error',{command:command.toString(16),field,message:error.message});this.emit('fieldError',{field,message:error.message});}
  }
  async refresh(){
    if(!this.connected)throw Error('Connect first');
    const byte=p=>{requireSuccess(p,2);if(p.length!==2)throw Error('Invalid byte reply');return p[1];};
    await this.read(0x0106,[],'battery',p=>{requireSuccess(p,2);return pairs(p,{status:true,battery:true});});
    await this.read(0x0105,[],'firmware',firmware);
    await this.read(0x0109,[],'wearing',p=>pairs(p));
    await this.read(0x010c,[1,1],'noise',noise);
    await this.read(0x010f,[],'eq',byte);
    await this.read(0x0122,[],'customPresets',customPresets);
    await this.read(0x0108,[],'gestures',gestures);
    await this.read(0x010d,[9,5,4,11,17,24,6,27,29,28],'features',featureStates);
    await this.read(0x0112,[],'devices',connectedDevices);
    await this.read(0x0114,[],'codec',byte);
    await this.read(0x0124,[],'bass',p=>{requireSuccess(p,4);if(p.length!==4||p[1]!==251||p[2]!==5)throw Error('Invalid BassWave reply');return p[3]>127?p[3]-256:p[3];});
    await this.read(0x0130,[],'promptVolume',byte);
    this.emit('refreshed',this.state);
  }
  async subscribe(){
    const p=await this.query(0x0200);requireSuccess(p,2);
    if(p.length!==p[1]+2)throw Error('Invalid offered-event list');
    this.offered=p.slice(2);this.record('offered_events',{ids:this.offered});
    const ids=[1,2,3].filter(id=>this.offered.includes(id));
    if(ids.length&&this.caps.supports(0x0205)){
      const ack=await this.query(0x0205,[ids.length,...ids]);
      this.record('subscription_ack',{ids,payload:ack});
      // Ack grammar is not yet fully known; only claim that an ack arrived.
      this.emit('subscribed',{ids});
    }
  }
}
