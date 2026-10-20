import {SERVICE,MODEL,encode,Framer,capabilities,requireSuccess,acknowledged,pairs,noise,holdCycle,smartLevel,
  featureStates,gestures,customPresets,connectedDevices,firmware,bassLevel,fitResult,goldenRecord,hearingEnhanceType,
  NOISE_REPORTS,SWITCHES,noiseModePayload,holdCycleMask,holdCyclePayload,gestureTablePayload,callGesturePayload,
  customEqPayload,bassPayload,tonePayload,hearingFilterPayload,hearingRecordPayload,hearingSnap,EQ_MAX_CUSTOM} from './protocol.js';
const delay = ms => new Promise(resolve=>setTimeout(resolve,ms));
const hex = command => command.toString(16).padStart(4,'0');
const byte=p=>{requireSuccess(p,2);if(p.length!==2)throw Error('Invalid byte reply');return p[1];};
const parsed=value=>{if(value==null)throw Error('Unrecognized reply');return value;};
const READS={
  battery:[0x0106,[],p=>{requireSuccess(p,2);return parsed(pairs(p,{status:true,battery:true}));}],
  firmware:[0x0105,[],firmware],
  wearing:[0x0109,[],p=>parsed(pairs(p))],
  noise:[0x010c,[1,1],noise],
  smartLevel:[0x010c,[4,1],smartLevel],
  holdCycle:[0x010c,[2,1],holdCycle],
  eq:[0x010f,[],byte],
  customPresets:[0x0122,[],customPresets],
  gestures:[0x0108,[],gestures],
  features:[0x010d,[9,5,4,11,17,24,6,27,29,28],featureStates],
  devices:[0x0112,[],connectedDevices],
  codec:[0x0114,[],byte],
  bass:[0x0124,[],bassLevel],
  promptVolume:[0x0130,[],byte],
  golden:[0x0115,[],p=>p[0]===0?goldenRecord(p):null],
};
const REFRESH=['battery','firmware','wearing','noise','smartLevel','holdCycle','eq','customPresets','gestures','features','devices','codec','bass','promptVolume','golden'];
export class BudsSession extends EventTarget {
  constructor(record=()=>{}) {
    super();this.record=record;this.port=null;this.reader=null;this.pending=new Map();
    this.sequence=1;this.queue=Promise.resolve();this.generation=0;this.connected=false;
    this.state={};this.events=0;this.closing=null;this.waiters=new Set();
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
    this.connected=false;++this.generation;clearTimeout(this.batteryTimer);
    for(const item of this.pending.values())item.reject(Error(reason));this.pending.clear();
    for(const waiter of this.waiters)waiter.reject(Error(reason));this.waiters.clear();
    const reader=this.reader;this.reader=null;
    this.emit('connection',{connected:false,reason,expected:!!this.expectDrop});
    this.closing=(async()=>{
      try{await reader?.cancel();}catch{}
      try{reader?.releaseLock();}catch{}
      try{await this.port?.close();}catch{}
      this.record('disconnected',{reason});this.queue=Promise.resolve();
    })();
    try{await this.closing;}finally{this.closing=null;}
  }
  // The buds restart their link after some changes; reopen the same granted port.
  async reconnect(timeout=25000) {
    const until=Date.now()+timeout;let last;
    while(Date.now()<until){
      await delay(2000);
      try{await this.connect(this.port);this.record('reconnected',{});return;}
      catch(error){last=error;if(/Buds 4 only/.test(error.message))throw error;}
    }
    throw Error(`The earbuds did not come back (${last?.message??'timeout'}). Connect again when they are ready.`);
  }
  query(command,payload=[],timeout=3500) {
    const generation=this.generation;
    const work=this.queue.catch(()=>{}).then(async()=>{
      if(!this.connected||generation!==this.generation)throw Error('Session changed');
      const sequence=this.sequence;this.sequence=sequence===254?1:sequence+1;
      const bytes=encode(command,sequence,payload),key=(command|0x8000)+':'+sequence;
      let timer;
      const answer=new Promise((resolve,reject)=>{
        this.pending.set(key,{resolve,reject});
        timer=setTimeout(()=>reject(Error(`No reply for ${hex(command)}`)),timeout);
      });answer.catch(()=>{});
      try{
        const writer=this.port.writable.getWriter();
        try{await writer.write(bytes);}finally{writer.releaseLock();}
        this.record('request',{command:hex(command),sequence,payload});
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
      if(p[0]===2){
        const wearing=pairs(p.slice(1));
        if(wearing){
          const before=this.state.wearing;patch={wearing:{...before,...wearing}};
          // The case reports battery only with its lid open, and opening it does not always push a battery event.
          const caseVisible=w=>!!(w?.case?.lidOpen||w?.left?.inCase&&w?.left?.lidOpen||w?.right?.inCase&&w?.right?.lidOpen);
          if(caseVisible(patch.wearing)&&!caseVisible(before)){
            clearTimeout(this.batteryTimer);
            this.batteryTimer=setTimeout(()=>{if(this.connected)this.read('battery');},800);
          }
        }
      }
      if(p[0]===3&&p[1]===1&&p[2]===1){try{patch={noise:noise([0,...p.slice(1)])};}catch{}}
      if(p[0]===3&&p[1]===2&&p[2]===1){try{patch={holdCycle:holdCycle([0,...p.slice(1)])};}catch{}}
      if(p[0]===3&&p[1]===4&&p[2]===1){try{patch={smartLevel:smartLevel([0,...p.slice(1)])};}catch{}}
      if(p[0]===4){patch={fit:fitResult(p.slice(1))};this.resolveWaiters('fit',patch.fit);}
      if(p[0]===5&&p.length===2){patch={features:{...this.state.features,6:p[1]}};}
      if(p[0]===8&&p.length>=3){patch={hearingStatus:{kind:p[1],status:p[2]}};this.emit('hearing',patch.hearingStatus);}
      if(patch){
        this.events++;this.setState(patch);this.emit('live',{code:p[0],events:this.events});
        this.record('live_event',{code:p[0],payload:p,events:this.events});return;
      }
    }
    if(frame.command===0x0504&&p.length===1&&this.state.model===MODEL){this.setState({eq:p[0]});this.events++;this.emit('live',{code:'eq',events:this.events});}
    else this.record('unhandled_frame',{command:frame.command.toString(16),sequence:frame.sequence,payloadLength:p.length});
  }
  waitFor(kind,timeout){
    return new Promise((resolve,reject)=>{
      const waiter={kind,resolve:value=>{clearTimeout(timer);this.waiters.delete(waiter);resolve(value);},
        reject:error=>{clearTimeout(timer);this.waiters.delete(waiter);reject(error);}};
      const timer=setTimeout(()=>waiter.reject(Error('No result from the earbuds in time')),timeout);
      this.waiters.add(waiter);
    });
  }
  resolveWaiters(kind,value){for(const waiter of [...this.waiters])if(waiter.kind===kind)waiter.resolve(value);}
  setState(patch) {Object.assign(this.state,patch,{updatedAt:new Date().toISOString()});this.emit('state',this.state);}
  async read(field){
    const [command,payload,decoder]=READS[field];
    if(!this.caps.supports(command)){this.record('query_skipped',{command:hex(command),reason:'not offered'});return;}
    try{const raw=await this.query(command,payload);const value=decoder(raw);if(value===undefined)throw Error('Unrecognized reply');if(this.state.errors)delete this.state.errors[field];this.setState({[field]:value});}
    catch(error){this.state.errors??={};this.state.errors[field]=error.message;this.record('query_error',{command:hex(command),field,message:error.message});this.emit('fieldError',{field,message:error.message});}
  }
  async refresh(){
    if(!this.connected)throw Error('Connect first');
    for(const field of REFRESH)await this.read(field);
    this.emit('refreshed',this.state);
  }
  async reread(field){
    await this.read(field);
    if(this.state.errors?.[field])throw Error(`Could not read back ${field}: ${this.state.errors[field]}`);
    return this.state[field];
  }
  async subscribe(){
    const p=await this.query(0x0200);requireSuccess(p,2);
    if(p.length!==p[1]+2)throw Error('Invalid offered-event list');
    this.offered=p.slice(2);this.record('offered_events',{ids:this.offered});
    const wanted=[1,2,3];
    if(this.caps.supports(0x0405))wanted.push(4);
    if(this.caps.supports(0x040d))wanted.push(8);
    const ids=wanted.filter(id=>this.offered.includes(id));
    if(ids.length&&this.caps.supports(0x0205)){
      const ack=await this.query(0x0205,[ids.length,...ids]);
      this.record('subscription_ack',{ids,payload:ack});
      // Ack grammar is not yet fully known; only claim that an ack arrived.
      this.subscribed=ids;this.emit('subscribed',{ids});
    }
  }

  // Changes. Each one requires the buds' acknowledgement and, where a read exists, a matching read-back:
  // an ack of 00 alone does not prove a write took.
  async send(name,command,payload){
    if(!this.connected)throw Error('Connect first');
    if(!this.caps.supports(command))throw Error(`${name} is not offered by these earbuds`);
    this.record('write',{name,command:hex(command),payload});
    try{return acknowledged(command,await this.query(command,payload));}
    catch(error){this.record('write_error',{name,command:hex(command),message:error.message,status:error.status});throw error;}
  }
  async change(name,command,payload,field,check){
    const ack=await this.send(name,command,payload);
    const value=await this.reread(field);
    if(!check(value)){
      this.record('write_unverified',{name,command:hex(command),field,readBack:value});
      throw Error(`${name}: the earbuds accepted the change but still report the old value`);
    }
    this.record('write_verified',{name,command:hex(command),field});
    return ack;
  }
  async setNoise(mode){
    await this.change(`Noise mode ${mode}`,0x0404,noiseModePayload(mode),'noise',v=>NOISE_REPORTS[mode].includes(v.raw));
    if(['smart','anc'].includes(mode))await this.read('smartLevel');
  }
  async setHoldCycle(modes){
    if(!modes.length)throw Error('Choose at least one mode for touch and hold');
    const mask=holdCycleMask(modes);
    await this.change('Touch-and-hold noise cycle',0x0404,holdCyclePayload(modes),'holdCycle',v=>v.mask===mask);
  }
  async setSwitch(name,id,on){
    await this.change(`${name} ${on?'on':'off'}`,0x0403,[id,on?1:0],'features',v=>v?.[id]===(on?1:0));
  }
  setWearDetection(on){return this.setSwitch('Wear detection',SWITCHES.wearDetection,on);}
  setGameMode(on){return this.setSwitch('Game mode',SWITCHES.gameMode,on);}
  setSmartVolume(on){return this.setSwitch('Smart volume',SWITCHES.smartVolume,on);}
  setBassWave(on){return this.setSwitch('BassWave',SWITCHES.bassWave,on);}
  setGoldenSound(on){return this.setSwitch('Golden Sound',SWITCHES.goldenSound,on);}
  async setDualConnection(on){
    await this.setSwitch('Dual connection',SWITCHES.dualConnection,on);
    // HeyMelody follows every toggle with this phone-state frame (auto switch flag); meaning partly unknown.
    await this.send('Dual connection follow-up',0x0413,[8,0,on?0:1]);
    await this.read('devices');
  }
  // Hi-Res and 3D audio are mutually exclusive; any Hi-Res change restarts the buds' link.
  async setSpatial(on){
    if(on&&this.state.features?.[SWITCHES.hiRes]===1){
      await this.setSwitch('OnePlus 3D Audio',SWITCHES.spatial,true);
      return this.writeHiRes(false);
    }
    return this.setSwitch('OnePlus 3D Audio',SWITCHES.spatial,on);
  }
  async setHiRes(on){
    if(on&&this.state.features?.[SWITCHES.spatial]===1)await this.setSwitch('OnePlus 3D Audio',SWITCHES.spatial,false);
    return this.writeHiRes(on);
  }
  async writeHiRes(on){
    const id=SWITCHES.hiRes,name=`Hi-Res audio ${on?'on':'off'}`;
    this.expectDrop=true;
    try{
      try{await this.send(name,0x0403,[id,on?1:0]);}
      catch(error){if(this.connected)throw error;}
      if(this.connected)await Promise.race([new Promise(r=>this.addEventListener('connection',r,{once:true})),delay(8000)]);
      if(!this.connected){this.emit('reconnecting',{reason:name});await this.reconnect();}
    }finally{this.expectDrop=false;}
    const value=await this.reread('features');
    if(value?.[id]!==(on?1:0))throw Error(`${name}: the earbuds still report the old value`);
    this.record('write_verified',{name,command:'0403',field:'features'});
  }
  async setGesture(side,action,fn){
    const table=this.state.gestures;
    if(!table)throw Error('Read the gesture table first');
    const device=side==='Left'?1:2;
    await this.change(`${side} ${action} gesture`,0x0401,gestureTablePayload(table,side,action,fn),'gestures',
      v=>{const slots=v.filter(e=>e.device===device&&e.action===action&&e.button!==6);return slots.length&&slots.every(e=>e.fn===fn);});
  }
  async setCallGesture(action,fn){
    await this.change(`Call gesture ${action}`,0x0401,callGesturePayload(action,fn),'gestures',
      v=>{const slots=v.filter(e=>e.button===6&&e.action===action);return slots.length&&slots.every(e=>e.fn===fn);});
  }
  setEq(id){return this.change(`Equalizer ${id}`,0x0406,[id],'eq',v=>v===id);}
  async createPreset(name,bands){
    if((this.state.customPresets?.length??0)>=EQ_MAX_CUSTOM)throw Error(`The earbuds hold at most ${EQ_MAX_CUSTOM} custom presets`);
    const before=new Set(this.state.customPresets?.map(p=>p.id));
    await this.change(`Create preset ${name}`,0x0418,customEqPayload('create',{name,bands}),'customPresets',
      v=>v.some(p=>!before.has(p.id)&&p.name===name));
    // Ids are renumbered after create/delete; always use the fresh list.
    return this.state.customPresets.find(p=>!before.has(p.id)&&p.name===name);
  }
  async savePreset(preset){
    const same=p=>p.id===preset.id&&p.name===preset.name&&p.bands.length===preset.bands.length&&p.bands.every((b,i)=>b.gain===preset.bands[i].gain);
    await this.change(`Save preset ${preset.name}`,0x0418,customEqPayload('save',preset),'customPresets',v=>v.some(same));
    await this.read('eq');
  }
  async deletePreset(preset){
    const remaining=this.state.customPresets.filter(p=>p.id!==preset.id).map(p=>p.name);
    await this.change(`Delete preset ${preset.name}`,0x0418,customEqPayload('delete',preset),'customPresets',
      v=>v.length===remaining.length&&!v.some(p=>p.id===preset.id&&p.name===preset.name));
    await this.read('eq');
  }
  setBass(level){return this.change(`BassWave level ${level}`,0x041b,bassPayload(level),'bass',v=>v===level);}
  // Every prompt-volume write plays a prompt in the ears.
  setPromptVolume(level){return this.change(`Prompt volume ${level}`,0x0427,[level],'promptVolume',v=>v===level);}

  // Actions with no persistent state; only the acknowledgement can be checked.
  findEarbuds(on){return this.send(on?'Find earbuds start':'Find earbuds stop',0x0400,[on?1:0]);}
  async fitTest(){
    if(!this.subscribed?.includes(4))throw Error('These earbuds did not accept fit-test results');
    const result=this.waitFor('fit',15000);result.catch(()=>{});
    await this.send('Fit test start',0x0405,[1]);
    try{return await result;}
    finally{if(this.connected)await this.send('Fit test stop',0x0405,[0]).catch(()=>{});}
  }
  hearingTest(on){return this.send(on?'Hearing test start':'Hearing test stop',0x040d,[2,on?1:0]);}
  async playTone(side,freq,value){
    await this.send('Hearing tone stop',0x040e,[4]);
    return this.send('Hearing tone',0x040e,tonePayload(side,freq,value));
  }
  stopTone(){return this.send('Hearing tone stop',0x040e,[4]);}
  // HeyMelody order: filter (gives the enhance type), restore id, record, then the switch on.
  async applyHearing(levels){
    if(levels.length!==12)throw Error('A hearing result needs 12 values');
    const values=levels.map(hearingSnap),uid=crypto.getRandomValues(new Uint32Array(1))[0];
    const now=new Date(),pad=n=>String(n).padStart(2,'0');
    const name=`${now.getFullYear()}/${pad(now.getMonth()+1)}/${pad(now.getDate())} ${pad(now.getHours())}:${pad(now.getMinutes())}`;
    if(!this.caps.supports(0x0116))throw Error('Golden Sound is not offered by these earbuds');
    const type=hearingEnhanceType(await this.query(0x0116,hearingFilterPayload(uid,values)));
    if(type>0)await this.send('Golden Sound restore',0x0411,[1,1,1,0,type]);
    await this.change('Golden Sound record',0x040e,hearingRecordPayload(uid,name,values),'golden',
      v=>v?.uid===uid&&v.values.every((x,i)=>x===values[i]));
    await this.setGoldenSound(true);
  }
}
