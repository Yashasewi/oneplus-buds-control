import {BudsSession} from './device.js';
const $=id=>document.getElementById(id);
const connect=$('connect'),disconnect=$('disconnect'),refresh=$('refresh'),message=$('message');
let ear='Left',busy=false,lastState=null;
const session=new BudsSession();
function note(text,error=false){message.textContent=text;message.classList.toggle('error',error);}
function resetUnknown(){
  ['battery-left','battery-right','battery-case'].forEach(id=>{const el=$(id);el.textContent='—';const unit=document.createElement('small');unit.textContent='%';el.append(unit);});
  ['noise-value','eq-value','bass-value','dual-value','firmware-info','codec-value','volume-value'].forEach(id=>$(id).textContent='Not checked');
  $('firmware').textContent='Firmware —';
  document.querySelectorAll('.mode-grid span').forEach(el=>el.classList.remove('selected'));
  for(const side of ['left','right','case'])$(`meter-${side}`).firstElementChild.style.height='0';
  $('features').replaceChildren();empty($('features'),'Your available features appear here after connecting.');
  $('devices').replaceChildren();empty($('devices'),'Connected devices appear here.');
  $('preset-list').replaceChildren();$('gestures').replaceChildren();empty($('gestures'),'Connect to read your current gestures.');
}
function empty(container,text){const p=document.createElement('p');p.className='empty';p.textContent=text;container.append(p);}
function renderGestures(state){
  const list=$('gestures');list.replaceChildren();
  const rows=state.gestures?.filter(x=>x.side===ear&&x.button!==6) ?? [];
  if(!rows.length){empty(list,state.gestures?'No gesture mappings reported for this ear.':'Not checked');return;}
  for(const row of rows){
    const el=document.createElement('div');el.className='gesture-row';
    const action=document.createElement('span');action.textContent=row.actionName;
    const fn=document.createElement('span');fn.textContent=row.functionName;el.append(action,fn);list.append(el);
  }
  const calls=state.gestures?.filter(x=>x.side===ear&&x.button===6)??[];
  if(calls.length){
    const heading=document.createElement('p');heading.className='call-heading';heading.textContent='DURING CALLS';list.append(heading);
    for(const row of calls){const el=document.createElement('div');el.className='gesture-row';const action=document.createElement('span');action.textContent=row.actionName;const fn=document.createElement('span');fn.textContent=row.functionName;el.append(action,fn);list.append(el);}
  }
}
export function render(state){
  lastState=state;
  for(const side of ['left','right','case']){
    const value=state.battery?.[side],el=$(`battery-${side}`);el.textContent=value?.percent??'—';
    const unit=document.createElement('small');unit.textContent='%';el.append(unit);
    $(`meter-${side}`).firstElementChild.style.height=`${value?.percent??0}%`;
    const wearing=state.wearing?.[side];
    $(`wear-${side}`).textContent=value?.charging?'Charging':side==='case'
      ? (wearing?.lidOpen?'Case open':value?.percent?'Last reported':'Open the case to check')
      : wearing?(wearing.inEar?'In your ear':wearing.inCase?'In the case':'Out of ear'):'Not checked';
  }
  if(state.firmware){$('firmware').textContent=`Firmware ${state.firmware}`;$('firmware-info').textContent=state.firmware;}
  if(state.noise){
    $('noise-value').textContent=state.noise.name;
    const mode=state.noise.name.startsWith('ANC')||state.noise.name==='Noise cancellation'?'Noise cancellation':state.noise.name;
    document.querySelectorAll('.mode-grid span').forEach(el=>el.classList.toggle('selected',el.dataset.mode===mode));
  }
  if(state.eq!==undefined)$('eq-value').textContent=({0:'Balanced',1:'Serenade',2:'Bass'})[state.eq]??state.customPresets?.find(x=>x.id===state.eq)?.name??`Preset ${state.eq}`;
  if(state.bass!==undefined)$('bass-value').textContent=`${state.bass>0?'+':''}${state.bass}`;
  if(state.customPresets){
    $('preset-list').replaceChildren();
    for(const preset of state.customPresets){const el=document.createElement('span');el.className='preset-tag';el.textContent=preset.name;$('preset-list').append(el);}
  }
  if(state.features){
    const list=$('features');list.replaceChildren();
    for(const [id,label] of [[4,'Wear detection'],[6,'Game mode'],[11,'Golden Sound'],[24,'Hi-Res audio'],[27,'OnePlus 3D Audio'],[29,'BassWave'],[28,'Smart volume']]){
      if(state.features[id]===undefined)continue;
      const el=document.createElement('div');el.className='feature-row';
      const name=document.createElement('span');name.textContent=label;
      const value=document.createElement('span');value.className='feature-state';
      value.classList.toggle('on',state.features[id]===1);value.textContent=state.features[id]===1?'On':state.features[id]===0?'Off':'Other state';
      el.append(name,value);list.append(el);
    }
    if(!list.children.length)empty(list,'No supported switches reported.');
    if(state.features[17]!==undefined)$('dual-value').textContent=state.features[17]===1?'On':state.features[17]===0?'Off':'Other state';
  }
  if(state.devices){
    const list=$('devices');list.replaceChildren();
    for(const device of state.devices){
      const row=document.createElement('div');row.className='device-row';
      const icon=document.createElement('span');icon.className='host-icon';icon.textContent='▣';
      const text=document.createElement('span');text.textContent=device.name||'Unnamed device';
      const status=document.createElement('small');status.textContent=[device.connected?'Connected':'Not connected',device.thisDevice?'This Mac':null,device.playing?'Playing audio':null].filter(Boolean).join(' · ');
      text.append(status);row.append(icon,text);list.append(row);
    }
    if(!list.children.length)empty(list,'No connected devices reported.');
  }
  if(state.codec!==undefined)$('codec-value').textContent=({1:'SBC',2:'AAC',3:'LDAC',4:'aptX',5:'aptX HD',6:'aptX Adaptive',7:'LHDC',8:'LHDC V5'})[state.codec]??'Unrecognized codec';
  if(state.promptVolume!==undefined)$('volume-value').textContent=`${state.promptVolume} / 10`;
  renderGestures(state);
  const fields={noise:['noise-value'],eq:['eq-value'],bass:['bass-value'],firmware:['firmware-info'],codec:['codec-value'],promptVolume:['volume-value']};
  for(const field of Object.keys(state.errors??{})){
    for(const id of fields[field]??[])$(id).textContent='Not reported';
    if(field==='noise')document.querySelectorAll('.mode-grid span').forEach(el=>el.classList.remove('selected'));
  }
  $('updated').textContent=`Last checked ${new Date(state.updatedAt).toLocaleTimeString([], {hour:'2-digit',minute:'2-digit'})}`;
}
session.addEventListener('connection',event=>{
  const active=event.detail.connected;
  $('connection').classList.toggle('active',active);$('connection').lastChild.textContent=active?' Connected':' Not connected';
  $('live-dot').classList.toggle('active',active);
  connect.hidden=active;disconnect.hidden=!active;refresh.disabled=!active||busy;
  $('device-status').textContent=active?'Connected to your Mac':'Not connected';
  $('hero-description').textContent=active?'Your earbuds, in sync. Current settings are shown below.':'A clear view of your sound. Connect to see what your earbuds are doing.';
  if(!active){
    // Last reads stay visible with an explicit stale label; never imply current state after loss.
    $('updated').textContent=lastState?'Last read · disconnected':'No device data read yet';
    if(event.detail.reason)note(event.detail.reason);
    connect.disabled=false;refresh.disabled=true;
  }
});
session.addEventListener('state',event=>render(event.detail));
session.addEventListener('live',()=>{$('device-status').textContent='Live updates connected';});
session.addEventListener('fieldError',()=>note('Some values were not reported. You can refresh to check again.'));
session.addEventListener('subscribed',()=>{$('device-status').textContent=session.events?'Live updates connected':'Waiting for live updates';});
session.addEventListener('refreshed',()=>{if(!busy)note('Device state refreshed.');});
connect.onclick=async()=>{
  if(busy)return;busy=true;connect.disabled=true;note('Select OnePlus Buds 4 in the device chooser.');
  try{
    const port=await session.choose();resetUnknown();lastState=null;
    note('Reading your earbuds…');await session.connect(port);note(Object.keys(session.state.errors??{}).length?'Connected. Some values were not reported. Refresh to check again.':'Connected. These are your current device settings.');
  }catch(error){note(error.name==='NotFoundError'?'No earbuds selected. Connect when you are ready.':error.message,error.name!=='NotFoundError');}
  finally{busy=false;connect.disabled=false;refresh.disabled=!session.connected;}
};
disconnect.onclick=()=>session.close('Disconnected. You can reconnect whenever you like.');
refresh.onclick=async()=>{
  if(busy)return;busy=true;refresh.disabled=true;note('Refreshing device state…');
  try{await session.refresh();render(session.state);note(Object.keys(session.state.errors??{}).length?'Some values were not reported. Previously read values may be stale.':'Device state refreshed.');}catch(error){note(error.message,true);}
  finally{busy=false;refresh.disabled=!session.connected;}
};
document.querySelectorAll('.ear-tab').forEach(button=>button.onclick=()=>{
  ear=button.dataset.ear;
  document.querySelectorAll('.ear-tab').forEach(el=>{const selected=el===button;el.classList.toggle('selected',selected);el.setAttribute('aria-pressed',String(selected));});
  renderGestures(lastState??{});
});
if(!navigator.serial||!isSecureContext||/Electron|T3Code/.test(navigator.userAgent)){
  connect.disabled=true;note('Open this page in Google Chrome on your Mac to connect your earbuds.');
}
