import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {Framer,encode,capabilities,pairs,noise,gestures,customPresets,featureStates} from '../web/protocol.js';

const captures=readFileSync(new URL('../docs/heymelody/evidence/browser-transport-results.jsonl',import.meta.url),'utf8')
  .trim().split('\n').map(JSON.parse)
  .filter(r=>r.session==='aa713cde-3ade-4ca4-a42f-3189cc6f8d54'&&r.event==='query_response');
test('original device captures decode across every possible stream split',()=>{
  for(const capture of captures){
    const bytes=Uint8Array.from(capture.frameHex.split(' ').map(x=>parseInt(x,16)));
    for(let split=0;split<=bytes.length;split++){
      const frames=[],parser=new Framer(f=>frames.push(f));
      parser.push(bytes.slice(0,split));parser.push(bytes.slice(split));
      assert.equal(frames.length,1);
      assert.equal(frames[0].command,parseInt(capture.command,16));
      assert.equal(frames[0].sequence,capture.sequence);
      assert.deepEqual(frames[0].payload,capture.payload);
    }
  }
});
test('capture battery and capability bitmap remain consistent',()=>{
  const battery=pairs(captures.find(r=>r.command==='8106').payload,{battery:true,status:true});
  assert.deepEqual(battery,{left:{percent:80,charging:false},right:{percent:80,charging:false}});
  const caps=capabilities(captures.find(r=>r.command==='8100').payload);
  assert.equal(caps.supports(0x0205),true);
  assert.equal(caps.supports(0x010c),true);
  assert.equal(caps.supports(0x0122),true);
});
test('all mutation/test/firmware groups rejected, including unknown commands',()=>{
  for(let cmd=0;cmd<=65535;cmd++){
    if([0x0100,0x0103,0x0105,0x0106,0x0108,0x0109,0x010c,0x010d,0x010f,0x0112,0x0114,0x0122,0x0124,0x0130,0x0200,0x0205].includes(cmd))continue;
    assert.throws(()=>encode(cmd,1));
  }
  assert.throws(()=>encode(0x0205,1,[1,4]));
  assert.throws(()=>encode(0x0205,1,[2,1,1]));
  assert.throws(()=>encode(0x010c,1,[2,3]));
  assert.throws(()=>encode(0x0100,1,[0]));
});
test('stream resynchronizes after noise, length mismatches and unsupported flags',()=>{
  const good=[170,7,0,0,0,129,1,0,0],bad=[170,7,0,0,0,129,1,1,0];
  const frames=[],parser=new Framer(f=>frames.push(f));
  parser.push(Uint8Array.from([9,7,8,...bad,...good,...good]));
  assert.equal(frames.length,2);
  const oversized=new Framer(()=>assert.fail('oversized input accepted'));
  oversized.push(new Uint8Array(65537));assert.equal(oversized.buffer.length,0);
});
test('LEB128 multi-byte boundaries and combined frames',()=>{
  const packet=encode(0x010d,12,[124,...Array(124).fill(5)]);
  // Synthetic receive fixture keeps protocol framing independent of any external implementation.
  const frames=[],parser=new Framer(f=>frames.push(f));
  parser.push(Uint8Array.from([...packet,...packet]));
  assert.equal(frames.length,2);assert.equal(frames[0].payload.length,125);
});
test('malformed feature/gesture/custom-EQ replies do not invent state',()=>{
  assert.throws(()=>featureStates([0,2,4,1]));
  assert.throws(()=>gestures([0,1,1,1,2]));
  assert.throws(()=>customPresets([0,1,1,250,6,4,20]));
  assert.equal(pairs([0,1,1,127],{status:true,battery:true}),null);
  assert.deepEqual(customPresets([0,0]),[]);
  assert.equal(noise([0,1,1,0,8]).name,'Adaptive');
  assert.throws(()=>noise([14,1,1,0,8]));
});
