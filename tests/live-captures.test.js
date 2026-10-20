import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {Framer,firmware,noise,gestures,featureStates,pairs,customPresets,connectedDevices} from '../web/protocol.js';
import {BudsSession} from '../web/device.js';
const rows=JSON.parse(readFileSync(new URL('../docs/heymelody/evidence/feature-validation-session.json',import.meta.url),'utf8'));
const response=command=>rows.find(r=>r.event==='response'&&r.command===command.toString(16)).payload;

test('live inventory decodes firmware, gestures, feature switches and empty custom EQ',()=>{
  assert.equal(firmware(response(0x8105)),'138.138.105');
  assert.equal(noise(response(0x810c)).name,'Off');
  const controls=gestures(response(0x8108));assert.equal(controls.length,18);
  assert.equal(controls.find(x=>x.side==='Left'&&x.action===2&&x.button===1).functionName,'Next track');
  assert.equal(controls.find(x=>x.side==='Right'&&x.action===5&&x.button===1).functionName,'Volume');
  assert.equal(featureStates(response(0x810d))[17],1);
  assert.deepEqual(customPresets(response(0x8122)),[]);
});
test('all recorded reply frames retain their identity under byte-at-a-time reads',()=>{
  for(const row of rows.filter(r=>r.event==='response'&&r.hex)){
    const parsed=[],framer=new Framer(frame=>parsed.push(frame));
    for(const b of row.hex.split(' '))framer.push(Uint8Array.of(parseInt(b,16)));
    assert.equal(parsed.length,1);
    assert.equal(parsed[0].command,parseInt(row.command,16));
    assert.deepEqual(parsed[0].payload,row.payload);
  }
});
test('captured live events update wearing, noise and battery without sequence assumptions',()=>{
  const session=new BudsSession();session.state.model='065414';
  for(const row of rows.filter(r=>r.event==='live_event'&&r.time<'2026-10-12T14:42:27Z')){
    session.receive({command:0x0204,sequence:16,payload:row.payload,bytes:[]});
  }
  assert.equal(session.events,8);
  assert.equal(session.state.noise.name,'Transparency');
  assert.equal(session.state.wearing.left.inEar,false);
  assert.equal(session.state.wearing.right.inEar,true);
  assert.equal(session.state.battery.left.percent,80);
});
test('synthetic privacy-safe device fixture validates length and flag handling',()=>{
  const name=Array.from(new TextEncoder().encode('Mac'));
  const p=[0,1,0,0,0,0,0,0,6,2,1,3,...name];
  assert.deepEqual(connectedDevices(p),[{name:'Mac',connected:true,thisDevice:true,playing:false}]);
  assert.throws(()=>connectedDevices([...p,0]));
});

class CapturePort {
  constructor({wrongModel=false}={}){this.wrongModel=wrongModel;this.sent=[];this.opened=false;}
  async open(){
    assert.equal(this.opened,false);this.opened=true;
    this.readable=new ReadableStream({start:controller=>{this.controller=controller;}});
    this.writable=new WritableStream({write:bytes=>{
      const command=bytes[4]|bytes[5]<<8;this.sent.push(command);
      let payload=response(command|0x8000);
      if(command===0x0103&&this.wrongModel)payload=[0,1,2,3];
      if(command===0x0100){payload=[...payload];payload[4]&=~32;} // omit redacted paired-device fixture
      const total=payload.length+7;
      const reply=Uint8Array.from([170,total,0,0,command&255,(command>>8)|128,bytes[6],payload.length,0,...payload]);
      this.controller.enqueue(reply.slice(0,4));this.controller.enqueue(reply.slice(4));
    }});
  }
  getInfo(){return {bluetoothServiceClassId:'0000079a-d102-11e1-9b23-00025b00a5a5'};}
  async close(){this.opened=false;}
}
test('session reconnects, reacquires stream locks and repeats inventory from fresh replies',async()=>{
  const port=new CapturePort(),session=new BudsSession();
  await session.connect(port);
  assert.equal(session.state.firmware,'138.138.105');
  assert.equal(session.state.gestures.length,18);
  await session.close();
  assert.equal(port.writable.locked,false);
  assert.equal(port.readable.locked,false);
  await session.connect(port);assert.equal(session.state.battery.right.percent,80);
  await session.close();assert.equal(port.opened,false);
});
test('wrong model closes the port before any feature queries',async()=>{
  const port=new CapturePort({wrongModel:true}),session=new BudsSession();
  await assert.rejects(session.connect(port),/Buds 4 only/);
  assert.deepEqual(port.sent,[0x0100,0x0103]);assert.equal(port.opened,false);
});
