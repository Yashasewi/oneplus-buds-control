// Protocol facts and provenance: docs/heymelody/{packet-analysis,quickbuds-reference}.md.
export const SERVICE = '0000079a-d102-11e1-9b23-00025b00a5a5';
export const MODEL = '065414';
const READ_COMMANDS = new Set([
  0x0100, 0x0103, 0x0105, 0x0106, 0x0108, 0x0109, 0x010c,
  0x010d, 0x010f, 0x0112, 0x0114, 0x0122, 0x0124, 0x0130, 0x0200,
]);
// 0205 registers session events only. No persistent-setting or test commands.
export function encode(command, sequence, payload = []) {
  if (!READ_COMMANDS.has(command) && command !== 0x0205) throw Error('Command outside read-only scope');
  if (!Number.isInteger(sequence) || sequence < 1 || sequence > 254) throw Error('Invalid sequence');
  if (!Array.isArray(payload) || payload.length > 512 || payload.some(x => !Number.isInteger(x) || x < 0 || x > 255)) throw Error('Invalid payload');
  if (command === 0x0205 && (payload[0] !== payload.length - 1 || payload.length < 2
    || payload.slice(1).some(x => ![1, 2, 3].includes(x)) || new Set(payload.slice(1)).size !== payload.length - 1)) throw Error('Invalid event subscription');
  if ([0x0100,0x0103,0x0105,0x0106,0x0108,0x0109,0x010f,0x0112,0x0114,0x0122,0x0124,0x0130,0x0200].includes(command) && payload.length) throw Error('Unexpected query payload');
  if (command === 0x010c && !(payload.length === 2 && [1, 2, 4].includes(payload[0]) && payload[1] === 1)) throw Error('Invalid noise query');
  if (command === 0x010d && (payload[0] !== payload.length - 1 || !payload.length)) throw Error('Invalid feature query');
  let size = 7 + payload.length, length = [];
  do { const byte = size & 127; size = Math.floor(size / 128); length.push(byte | (size ? 128 : 0)); } while (size);
  return Uint8Array.from([0xaa, ...length, 0, 0, command & 255, command >> 8, sequence, payload.length & 255, payload.length >> 8, ...payload]);
}
export class Framer {
  constructor(onFrame, onInvalid = () => {}) { this.buffer = []; this.onFrame = onFrame; this.onInvalid = onInvalid; }
  push(chunk) {
    if (chunk.length > 65536 || this.buffer.length + chunk.length > 65536) {
      this.buffer = []; this.onInvalid('Receive buffer limit'); return;
    }
    this.buffer.push(...chunk);
    while (this.buffer.length) {
      if (this.buffer[0] !== 0xaa) { this.buffer.shift(); continue; }
      let size = 0, count = 0, complete = false;
      for (let i = 1; i < this.buffer.length && i <= 3; i++) {
        const byte = this.buffer[i]; size += (byte & 127) * 2 ** (7 * count++);
        if (!(byte & 128)) { complete = true; break; }
      }
      if (!complete) { if (this.buffer.length >= 4) { this.buffer.shift(); continue; } return; }
      if (size < 7 || size > 8192) { this.buffer.shift(); this.onInvalid('Invalid frame size'); continue; }
      const prefix = 1 + count, total = prefix + size;
      if (this.buffer.length < total) return;
      const bytes = this.buffer.splice(0, total), n = bytes[prefix + 5] | bytes[prefix + 6] << 8;
      if (bytes[prefix] || bytes[prefix + 1] || n !== size - 7) { this.onInvalid('Unsupported flags or inconsistent length'); continue; }
      this.onFrame({ command: bytes[prefix + 2] | bytes[prefix + 3] << 8, sequence: bytes[prefix + 4],
        payload: bytes.slice(prefix + 7), bytes });
    }
  }
}
export function requireSuccess(p, minimum = 1) {
  if (p.length < minimum) throw Error('Incomplete reply');
  if (p[0] !== 0) throw Error(`Device declined query (status ${p[0]})`);
}
export function pairs(p, {status = false, battery = false} = {}) {
  const offsets = status ? [1] : [0, 1];
  for (const offset of offsets) {
    if (offset === 1 && p[0] !== 0) continue;
    const count = p[offset];
    if (!Number.isInteger(count) || count > 3 || p.length !== offset + 1 + 2 * count) continue;
    const result = {}, seen = new Set();
    for (let i = 0; i < count; i++) {
      const id = p[offset + 1 + i * 2], value = p[offset + 2 + i * 2];
      if (id < 1 || id > 3 || seen.has(id) || (battery && (value & 127) > 100)) return null;
      seen.add(id);
      result[['','left','right','case'][id]] = battery
        ? {percent:(value & 127) || null, charging:!!(value & 128)}
        : {raw:value, inEar:!!(value & 2), inCase:!(value & 1), lidOpen:!!(value & 4)};
    }
    return result;
  }
  return null;
}
const CAP_BITS = new Map([[0x0105,0],[0x0108,3],[0x0109,4],[0x010c,8],[0x010f,10],
  [0x0112,29],[0x0114,17],[0x0122,34],[0x0124,38],[0x0130,57],[0x0205,22]]);
export function capabilities(p) {
  requireSuccess(p, 2);
  return {bitmap:p.slice(1), supports(command) {
    const bit = CAP_BITS.get(command);
    return bit === undefined ? READ_COMMANDS.has(command) : !!(p[1 + Math.floor(bit / 8)] & 1 << (bit % 8));
  }};
}
export const NOISE_NAMES = new Map([[8,'Off'],[2,'Noise cancellation'],[16,'ANC · Deep'],[32,'ANC · Medium'],
  [64,'ANC · Light'],[128,'ANC · Smart'],[256,'Transparency'],[512,'Voice transparency'],[2048,'Adaptive']]);
export function noise(p) {
  requireSuccess(p, 4);
  if (p[1] !== 1 || p[2] !== 1 || p.length > 7) throw Error('Unrecognized noise reply');
  const raw = p.slice(3).reduce((value,b,i) => value + b * 2 ** (8 * i), 0);
  return {raw, name:NOISE_NAMES.get(raw) ?? 'Unrecognized mode'};
}
export function featureStates(p) {
  requireSuccess(p,2);
  if (p.length !== 2 + p[1] * 2) throw Error('Invalid feature count');
  const result = {}, seen = new Set();
  for (let i=2; i<p.length; i+=2) {
    if (seen.has(p[i])) throw Error('Duplicate feature');
    seen.add(p[i]); result[p[i]] = p[i+1];
  }
  return result;
}
export const ACTIONS = {1:'Single tap',2:'Double tap',3:'Triple tap',4:'Touch and hold',5:'Slide',6:'Long hold'};
export const FUNCTIONS = {0:'No action',1:'Play / pause',3:'Voice assistant',5:'Previous track',6:'Next track',
  7:'Volume',8:'Noise control',10:'Switch tracks',11:'Volume up',12:'Volume down',13:'Switch devices',
  17:'Game mode',28:'Decline call',29:'Answer / end call'};
export function gestures(p) {
  requireSuccess(p,2);
  if (p[1] > 64 || p.length !== 2 + p[1] * 4) throw Error('Invalid gesture table');
  const entries = [];
  for (let i=2;i<p.length;i+=4) {
    const [side,button,action,fn] = p.slice(i,i+4);
    if (![1,2,4].includes(side)) throw Error('Invalid gesture side');
    entries.push({side:({1:'Left',2:'Right',4:'Both'})[side],button,action,fn,
      actionName:ACTIONS[action] ?? 'Other gesture',functionName:FUNCTIONS[fn] ?? 'Other function'});
  }
  return entries;
}
export function customPresets(p) {
  requireSuccess(p,2);
  if (p[1] > 10) throw Error('Invalid preset count');
  let cursor=2; const result=[];
  for (let i=0;i<p[1];i++) {
    if (cursor+5>p.length) throw Error('Truncated preset');
    const [selected,lo,hi,id,nameLength]=p.slice(cursor,cursor+5); cursor+=5;
    if (cursor+nameLength+1>p.length) throw Error('Truncated preset name');
    const name=new TextDecoder().decode(Uint8Array.from(p.slice(cursor,cursor+nameLength)));cursor+=nameLength;
    const count=p[cursor++]; if (count>16 || cursor+count*3>p.length) throw Error('Truncated preset bands');
    const bands=[];
    for(let b=0;b<count;b++){ const frequency=p[cursor]|p[cursor+1]<<8,g=p[cursor+2];cursor+=3;bands.push({frequency,gain:g>127?g-256:g}); }
    result.push({id,name,selected:selected===1,range:[lo>127?lo-256:lo,hi>127?hi-256:hi],bands});
  }
  if(cursor!==p.length) throw Error('Unexpected preset suffix');
  return result;
}
export function connectedDevices(p) {
  requireSuccess(p,2);
  if(p[1]>10)throw Error('Invalid device count');
  let cursor=2;const result=[];
  for(let i=0;i<p[1];i++){
    if(cursor+10>p.length)throw Error('Truncated connected device');
    const length=p[cursor+6],state=p[cursor+7],flags=p[cursor+8],n=p[cursor+9];
    if(length!==3+n || cursor+10+n>p.length)throw Error('Invalid device name length');
    const name=new TextDecoder().decode(Uint8Array.from(p.slice(cursor+10,cursor+10+n)));
    result.push({name,connected:state===2,thisDevice:!!(flags&1),playing:!!(flags&4)});
    cursor+=10+n;
  }
  if(cursor!==p.length)throw Error('Unexpected device suffix');
  return result;
}
export function firmware(p) {
  requireSuccess(p,3);
  const text=new TextDecoder().decode(Uint8Array.from(p.slice(2)));
  const parts=text.split(','),versions=[];
  if(parts.length%3)throw Error('Unrecognized firmware record');
  for(let i=0;i<parts.length;i+=3)if(parts[i+1].trim()==='2')versions.push(parts[i+2].trim());
  if(!versions.length || versions.some(x=>!/^\d+$/.test(x)))throw Error('Unrecognized firmware version');
  return versions.join('.');
}
