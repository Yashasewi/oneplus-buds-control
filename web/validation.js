import {BudsSession} from './device.js';
const id=crypto.randomUUID(),start=document.querySelector('#start'),stop=document.querySelector('#stop');
const status=document.querySelector('#status'),state=document.querySelector('#state'),log=document.querySelector('#log');
let stopped=false;
const sendQueue=[];
let sending=false;
function record(event,details={}){
  const item={session:id,event,time:new Date().toISOString(),...details};
  log.textContent+=JSON.stringify(item)+'\n';sendQueue.push(item);flush();
}
async function flush(){
  if(sending)return;sending=true;
  while(sendQueue.length){const item=sendQueue[0];try{const r=await fetch('/api/evidence',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(item)});if(!r.ok)break;sendQueue.shift();}catch{break;}}
  sending=false;
}
const session=new BudsSession(record);
session.addEventListener('state',event=>{
  // Device names are useful on screen, but are not copied into the evidence summary.
  state.textContent=JSON.stringify(event.detail,null,2);
});
session.addEventListener('live',event=>{status.textContent=`Live event received (${event.detail.events}). Keep wearing/removing one bud normally during the listening window.`;});
record('browser',{userAgent:navigator.userAgent,secureContext:isSecureContext,serialAvailable:!!navigator.serial});
stop.onclick=async()=>{stopped=true;await session.close('User stopped validation');status.textContent='Stopped.';stop.disabled=true;start.disabled=false;};
start.onclick=async()=>{
  start.disabled=true;stop.disabled=false;stopped=false;
  try{
    const port=await session.choose();status.textContent='Reading device state…';
    await session.connect(port);
    const summary={...session.state,devices:session.state.devices?.map(x=>({connected:x.connected,thisDevice:x.thisDevice,playing:x.playing}))};
    record('inventory_complete',{state:summary,offered:session.offered});
    status.textContent='Listening for 45 seconds. Take one bud out of your ear and put it back to check live wearing updates.';
    await new Promise(resolve=>setTimeout(resolve,45000));
    if(stopped)return;
    const liveEvents=session.events;record('listen_complete',{liveEvents});
    status.textContent='Reconnecting once…';await session.close('Reconnect validation');
    await new Promise(resolve=>setTimeout(resolve,700));
    if(stopped)return;
    await session.connect(port);
    record('reconnect_verified',{model:session.state.model,battery:session.state.battery,noise:session.state.noise});
    await session.close('Validation finished');
    record('validation_passed',{liveEvents,reconnect:true,model:session.state.model});
    status.textContent=liveEvents?'Read checks, live updates and reconnection passed.':'Read checks and reconnection passed. No live event occurred during the listening window.';
  }catch(error){record('validation_error',{message:error.message,name:error.name});status.textContent=error.name==='NotFoundError'?'No device selected. Try again when ready.':error.message;await session.close('Validation error');}
  finally{stop.disabled=true;start.disabled=false;await flush();}
};
