import {BudsSession} from './device.js';
import {GESTURE_MENUS,CALL_MENUS,FUNCTIONS,ACTIONS,SWITCHES,EQ_BANDS,EQ_GAIN,EQ_MAX_CUSTOM,
  HEARING_STOPS,HEARING_START,HEARING_LOUD} from './protocol.js';
const $=id=>document.getElementById(id);
const connect=$('connect'),disconnect=$('disconnect'),refresh=$('refresh'),message=$('message');
let ear='Left',busy=false,lastState=null,ringing=false;
const session=new BudsSession();
const BUILT_IN_EQ={0:'Balanced',1:'Serenade',2:'Bass'};
const ANC_LEVELS=['smart','deep','medium','light','anc'];
const LEVEL_NAMES={smart:'Smart',deep:'Deep',medium:'Medium',light:'Light'};
const FEATURE_ROWS=[[SWITCHES.wearDetection,'Wear detection'],[SWITCHES.gameMode,'Game mode'],[SWITCHES.goldenSound,'Golden Sound'],
  [SWITCHES.hiRes,'Hi-Res audio'],[SWITCHES.spatial,'OnePlus 3D Audio'],[SWITCHES.smartVolume,'Smart volume']];
function note(text,error=false){message.textContent=text;message.classList.toggle('error',error);}
function syncControls(){
  const active=session.connected&&!busy;
  document.querySelectorAll('[data-control]').forEach(el=>{el.disabled=!active;});
  refresh.disabled=!active;
}
async function run(label,work,success='Done. The earbuds confirmed the change.'){
  if(busy||!session.connected)return;
  busy=true;syncControls();note(`${label}…`);
  try{const result=await work();note(typeof success==='function'?success(result):success);}
  catch(error){note(error.message,true);}
  finally{busy=false;render(session.state);}
}
function el(tag,props={},...children){const node=Object.assign(document.createElement(tag),props);node.append(...children);return node;}
function empty(container,text){container.append(el('p',{className:'empty',textContent:text}));}
function setToggle(button,value){
  button.setAttribute('aria-checked',String(value===1));
  button.classList.toggle('unknown',value!==0&&value!==1);
}
function toggle(label,value,onChange){
  const button=el('button',{className:'toggle',role:'switch',ariaLabel:label});
  button.dataset.control='';setToggle(button,value);
  button.onclick=()=>onChange(value!==1);return button;
}
function resetUnknown(){
  ['battery-left','battery-right','battery-case'].forEach(id=>{const node=$(id);node.textContent='—';node.append(el('small',{textContent:'%'}));});
  ['noise-value','eq-value','bass-value','firmware-info','codec-value','volume-value','golden-value'].forEach(id=>$(id).textContent='Not checked');
  $('fit-value').textContent='';
  $('firmware').textContent='Firmware —';
  for(const side of ['left','right','case'])$(`meter-${side}`).firstElementChild.style.height='0';
  $('features').replaceChildren();empty($('features'),'Your available features appear here after connecting.');
  $('devices').replaceChildren();empty($('devices'),'Connected devices appear here.');
  $('preset-list').replaceChildren();$('gestures').replaceChildren();empty($('gestures'),'Connect to read your current gestures.');
}
function gestureSelect(current,menu,onChange,label){
  const select=el('select',{ariaLabel:label});select.dataset.control='';
  const options=menu.includes(current)?menu:[current,...menu];
  for(const fn of options)select.append(el('option',{value:fn,textContent:FUNCTIONS[fn]??`Function ${fn}`,disabled:!menu.includes(fn)}));
  select.value=String(current);
  select.onchange=()=>onChange(Number(select.value));
  return select;
}
function renderGestures(state){
  const list=$('gestures');list.replaceChildren();
  if(!state.gestures){empty(list,'Not checked');return;}
  let rows=0;
  for(const action of [1,2,3,5,4]){
    const slot=state.gestures.find(x=>x.side===ear&&x.button!==6&&x.action===action);
    if(!slot)continue;rows++;
    list.append(el('div',{className:'gesture-row'},el('span',{textContent:ACTIONS[action]}),
      gestureSelect(slot.fn,GESTURE_MENUS[action],fn=>run(`Changing ${ACTIONS[action].toLowerCase()}`,()=>session.setGesture(ear,action,fn)),`${ear} ${ACTIONS[action]}`)));
  }
  if(!rows)empty(list,'No gesture mappings reported for this ear.');
  const calls=Object.keys(CALL_MENUS).map(Number).map(action=>[action,state.gestures.find(x=>x.button===6&&x.action===action)]).filter(([,slot])=>slot);
  if(calls.length){
    list.append(el('p',{className:'call-heading',textContent:'DURING CALLS · BOTH EARBUDS'}));
    for(const [action,slot] of calls)list.append(el('div',{className:'gesture-row'},el('span',{textContent:ACTIONS[action]}),
      gestureSelect(slot.fn,CALL_MENUS[action],fn=>run('Changing call control',()=>session.setCallGesture(action,fn)),`Call ${ACTIONS[action]}`)));
  }
}
function renderPresets(state){
  const list=$('preset-list');list.replaceChildren();
  const presets=[...Object.entries(BUILT_IN_EQ).map(([id,name])=>({id:Number(id),name})),...(state.customPresets??[]).map(p=>({...p,custom:true}))];
  for(const preset of presets){
    const button=el('button',{className:'chip',textContent:preset.name,ariaPressed:String(state.eq===preset.id)});
    button.dataset.control='';button.classList.toggle('selected',state.eq===preset.id);
    button.onclick=()=>state.eq===preset.id&&preset.custom?openPreset(preset):run(`Selecting ${preset.name}`,()=>session.setEq(preset.id));
    if(preset.custom)button.title='Select, then click again to edit';
    list.append(button);
  }
  if(state.customPresets&&state.customPresets.length<EQ_MAX_CUSTOM){
    const add=el('button',{className:'chip add',textContent:'+ New preset'});add.dataset.control='';add.onclick=()=>openPreset(null);list.append(add);
  }
}
export function render(state){
  lastState=state;
  for(const side of ['left','right','case']){
    const value=state.battery?.[side],node=$(`battery-${side}`);node.textContent=value?.percent??'—';
    node.append(el('small',{textContent:'%'}));
    $(`meter-${side}`).firstElementChild.style.height=`${value?.percent??0}%`;
    const wearing=state.wearing?.[side];
    $(`wear-${side}`).textContent=value?.charging?'Charging':side==='case'
      ? (wearing?.lidOpen?'Case open':value?.percent?'Last reported':'Open the case to check')
      : wearing?(wearing.inEar?'In your ear':wearing.inCase?'In the case':'Out of ear'):'Not checked';
  }
  if(state.firmware){$('firmware').textContent=`Firmware ${state.firmware}`;$('firmware-info').textContent=state.firmware;}
  const mode=state.noise?.mode,group=ANC_LEVELS.includes(mode)?'anc':mode;
  document.querySelectorAll('[data-noise]').forEach(b=>{b.classList.toggle('selected',b.dataset.noise===group);b.setAttribute('aria-pressed',String(b.dataset.noise===group));});
  $('anc-levels').hidden=group!=='anc';
  document.querySelectorAll('[data-level]').forEach(b=>b.classList.toggle('selected',b.dataset.level===mode));
  if(state.noise)$('noise-value').textContent=mode==='smart'&&state.smartLevel&&LEVEL_NAMES[state.smartLevel]?`ANC · Smart (${LEVEL_NAMES[state.smartLevel]} now)`:state.noise.name;
  document.querySelectorAll('[data-hold]').forEach(box=>{box.checked=!!state.holdCycle?.modes.includes(box.dataset.hold);box.indeterminate=!state.holdCycle;});
  if(state.eq!==undefined)$('eq-value').textContent=BUILT_IN_EQ[state.eq]??state.customPresets?.find(x=>x.id===state.eq)?.name??`Preset ${state.eq}`;
  renderPresets(state);
  setToggle($('bass-toggle'),state.features?.[SWITCHES.bassWave]);
  if(state.bass!==undefined){$('bass-value').textContent=`${state.bass>0?'+':''}${state.bass}`;$('bass-level').value=state.bass;}
  if(state.features){
    const list=$('features');list.replaceChildren();
    for(const [id,label] of FEATURE_ROWS){
      if(state.features[id]===undefined)continue;
      list.append(el('div',{className:'feature-row'},el('span',{textContent:label}),toggle(label,state.features[id],on=>changeFeature(id,label,on))));
    }
    if(!list.children.length)empty(list,'No supported switches reported.');
  }
  setToggle($('dual-toggle'),state.features?.[SWITCHES.dualConnection]);
  if(state.devices){
    const list=$('devices');list.replaceChildren();
    for(const device of state.devices){
      const text=el('span',{textContent:device.name||'Unnamed device'});
      text.append(el('small',{textContent:[device.connected?'Connected':'Not connected',device.thisDevice?'This Mac':null,device.playing?'Playing audio':null].filter(Boolean).join(' · ')}));
      list.append(el('div',{className:'device-row'},el('span',{className:'host-icon',textContent:'▣'}),text));
    }
    if(!list.children.length)empty(list,'No connected devices reported.');
  }
  if(state.codec!==undefined)$('codec-value').textContent=({1:'SBC',2:'AAC',3:'LDAC',4:'aptX',5:'aptX HD',6:'aptX Adaptive',7:'LHDC',8:'LHDC V5'})[state.codec]??'Unrecognized codec';
  if(state.promptVolume!==undefined){$('volume-value').textContent=`${state.promptVolume} / 10`;$('volume-level').value=state.promptVolume;}
  if('golden' in state||state.errors?.golden)$('golden-value').textContent=state.golden?`Profile ${state.golden.name}`:'No hearing profile';
  if(state.fit)$('fit-value').textContent=`L: ${state.fit.left??'—'} · R: ${state.fit.right??'—'}`;
  $('find').textContent=ringing?'Stop ringing':'Ring';
  renderGestures(state);
  const fields={noise:['noise-value'],eq:['eq-value'],bass:['bass-value'],firmware:['firmware-info'],codec:['codec-value'],promptVolume:['volume-value']};
  for(const field of Object.keys(state.errors??{}))for(const id of fields[field]??[])$(id).textContent='Not reported';
  if(state.updatedAt)$('updated').textContent=`Last checked ${new Date(state.updatedAt).toLocaleTimeString([], {hour:'2-digit',minute:'2-digit'})}`;
  syncControls();
}
function changeFeature(id,label,on){
  const features=session.state.features??{};
  if(id===SWITCHES.hiRes){
    if(!confirm(`Turning Hi-Res audio ${on?'on':'off'} restarts the earbuds’ connection for a few seconds.${on&&features[SWITCHES.spatial]===1?' OnePlus 3D Audio will be turned off.':''}`))return render(session.state);
    return run(`Turning Hi-Res audio ${on?'on':'off'}`,()=>session.setHiRes(on));
  }
  if(id===SWITCHES.spatial){
    if(on&&features[SWITCHES.hiRes]===1&&!confirm('OnePlus 3D Audio and Hi-Res cannot be on together. Hi-Res will be turned off, which restarts the earbuds’ connection.'))return render(session.state);
    return run(`Turning ${label} ${on?'on':'off'}`,()=>session.setSpatial(on));
  }
  if(id===SWITCHES.goldenSound&&on&&!session.state.golden&&!confirm('No hearing profile was read from the earbuds. Turn Golden Sound on anyway? Run the hearing test to create one.'))return render(session.state);
  const setters={[SWITCHES.wearDetection]:'setWearDetection',[SWITCHES.gameMode]:'setGameMode',[SWITCHES.goldenSound]:'setGoldenSound',[SWITCHES.smartVolume]:'setSmartVolume'};
  return run(`Turning ${label} ${on?'on':'off'}`,()=>session[setters[id]](on));
}

document.querySelectorAll('[data-noise]').forEach(b=>b.onclick=()=>{
  const mode=b.dataset.noise;
  run(`Switching to ${b.textContent}`,()=>session.setNoise(mode));
});
document.querySelectorAll('[data-level]').forEach(b=>b.onclick=()=>run(`Setting noise cancelling to ${b.textContent}`,()=>session.setNoise(b.dataset.level)));
document.querySelectorAll('[data-hold]').forEach(box=>box.onchange=()=>{
  const modes=[...document.querySelectorAll('[data-hold]')].filter(x=>x.checked).map(x=>x.dataset.hold);
  if(!modes.length){box.checked=true;note('Touch and hold needs at least one mode.',true);return;}
  run('Updating the touch-and-hold cycle',()=>session.setHoldCycle(modes));
});
$('bass-toggle').onclick=()=>{const on=session.state.features?.[SWITCHES.bassWave]!==1;run(`Turning BassWave ${on?'on':'off'}`,()=>session.setBassWave(on));};
$('bass-level').onchange=event=>run('Setting BassWave level',()=>session.setBass(Number(event.target.value)));
$('volume-level').onchange=event=>run('Setting prompt volume (a prompt will play)',()=>session.setPromptVolume(Number(event.target.value)));
$('dual-toggle').onclick=()=>{
  const on=session.state.features?.[SWITCHES.dualConnection]!==1;
  if(!on&&!confirm('Turning dual connection off can disconnect your other device.'))return;
  run(`Turning dual connection ${on?'on':'off'}`,()=>session.setDualConnection(on));
};
$('find').onclick=()=>{
  if(!ringing&&!confirm('Your earbuds will ring loudly. Take them out of your ears first.'))return;
  const on=!ringing;
  run(on?'Ringing your earbuds':'Stopping the ring',async()=>{await session.findEarbuds(on);ringing=on;},on?'Ringing. Press Stop ringing when you find them.':'Stopped ringing.');
};
$('fit').onclick=()=>{
  if(!confirm('Wear both earbuds. A short sound will play while the fit is measured.'))return;
  run('Checking fit (about 10 seconds)',()=>session.fitTest(),result=>`Fit check finished. Left: ${result.left??'not measured'}. Right: ${result.right??'not measured'}.`);
};

// Custom preset editor.
let editing=null;
function openPreset(preset){
  editing=preset;
  $('preset-title').textContent=preset?`Edit ${preset.name}`:'New preset';
  $('preset-name').value=preset?.name??`Custom ${(session.state.customPresets?.length??0)+1}`;
  $('preset-delete').hidden=!preset;
  const bands=preset?.bands??EQ_BANDS.map(frequency=>({frequency,gain:0}));
  $('preset-bands').replaceChildren(...bands.map(({frequency,gain})=>{
    const input=el('input',{type:'range',min:-EQ_GAIN,max:EQ_GAIN,step:1,value:gain,ariaLabel:`${frequency} Hz`});
    input.dataset.frequency=frequency;
    const value=el('output',{textContent:gain});input.oninput=()=>{value.textContent=input.value;};
    return el('label',{className:'band'},value,input,el('span',{textContent:frequency>=1000?`${frequency/1000}k`:String(frequency)}));
  }));
  $('preset-dialog').showModal();
}
$('preset-cancel').onclick=()=>$('preset-dialog').close();
$('preset-form').onsubmit=event=>{
  event.preventDefault();
  const name=$('preset-name').value.trim();
  if(!/^[ -~]{1,16}$/.test(name)){note('Use up to 16 plain letters, digits or symbols for the name.',true);return;}
  const bands=[...$('preset-bands').querySelectorAll('input')].map(x=>({frequency:Number(x.dataset.frequency),gain:Number(x.value)}));
  const target=editing;$('preset-dialog').close();
  run(target?`Saving ${name}`:`Creating ${name}`,async()=>{
    const preset=target??await session.createPreset(name,bands.map(b=>({...b,gain:0})));
    await session.savePreset({...preset,name,bands});
  });
};
$('preset-delete').onclick=()=>{
  const target=editing;$('preset-dialog').close();
  if(target&&confirm(`Delete ${target.name}?`))run(`Deleting ${target.name}`,()=>session.deletePreset(target));
};

// Golden Sound hearing test: 6 tones per ear, then the result is applied and read back.
const hearing={step:-1,levels:[],timer:null,warned:false};
const hearingSide=step=>step<6?1:2;
function hearingNote(text){$('hearing-note').textContent=text;}
function showHearingStep(){
  const {step}=hearing;
  $('hearing-step').textContent=step<0?'Wear both earbuds in a quiet place.':`${step<6?'Left':'Right'} ear · tone ${step%6+1} of 6`;
  $('hearing-level').hidden=step<0;$('hearing-back').hidden=step<=0;
  $('hearing-next').textContent=step<0?'Start':step===11?'Finish and apply':'Next';
  $('hearing-level').value=hearing.levels[step]??HEARING_START;
}
async function playHearingTone(){
  const index=Number($('hearing-level').value);
  if(index>=HEARING_LOUD&&!hearing.warned){hearing.warned=true;hearingNote('This level is loud. Lower it if it is uncomfortable.');}
  try{await session.playTone(hearingSide(hearing.step),hearing.step%6+1,HEARING_STOPS[index]);}
  catch(error){hearingNote(error.message);}
}
async function endHearing(){
  clearTimeout(hearing.timer);
  if(hearing.step>=0&&session.connected){await session.stopTone().catch(()=>{});await session.hearingTest(false).catch(()=>{});}
  hearing.step=-1;busy=false;syncControls();
}
$('hearing').onclick=()=>{hearing.step=-1;hearing.levels=[];hearing.warned=false;hearingNote('');showHearingStep();$('hearing-dialog').showModal();};
$('hearing-level').oninput=()=>{clearTimeout(hearing.timer);hearing.timer=setTimeout(playHearingTone,300);};
$('hearing-cancel').onclick=()=>$('hearing-dialog').close();
$('hearing-dialog').onclose=()=>{if(hearing.step>=0)endHearing().then(()=>note('Hearing test cancelled. Nothing was changed.'));};
$('hearing-back').onclick=()=>{hearing.levels[hearing.step]=Number($('hearing-level').value);hearing.step--;showHearingStep();playHearingTone();};
$('hearing-next').onclick=async()=>{
  if(hearing.step<0){
    if(busy||!session.connected)return;
    busy=true;syncControls();
    try{await session.hearingTest(true);}catch(error){busy=false;syncControls();hearingNote(error.message);return;}
    hearing.step=0;showHearingStep();hearingNote('');playHearingTone();return;
  }
  hearing.levels[hearing.step]=Number($('hearing-level').value);
  if(hearing.step<11){hearing.step++;showHearingStep();playHearingTone();return;}
  const levels=hearing.levels.map(i=>HEARING_STOPS[i]);
  await endHearing();$('hearing-dialog').close();
  run('Applying your Golden Sound profile',()=>session.applyHearing(levels),'Golden Sound profile applied and confirmed by the earbuds.');
};
session.addEventListener('hearing',event=>{
  const text={5:'An earbud is out of your ear. Put it back to continue.',6:'Earbud back in. Continue.',7:'The test timed out. Cancel and start again.'}[event.detail.status];
  if(text)hearingNote(text);
});

session.addEventListener('connection',event=>{
  const active=event.detail.connected;
  $('connection').classList.toggle('active',active);$('connection').lastChild.textContent=active?' Connected':' Not connected';
  $('live-dot').classList.toggle('active',active);
  connect.hidden=active;disconnect.hidden=!active;
  $('device-status').textContent=active?'Connected to your Mac':'Not connected';
  $('hero-description').textContent=active?'Your earbuds, in sync. Change any setting below.':'A clear view of your sound. Connect to see what your earbuds are doing.';
  if(!active){
    ringing=false;
    if($('hearing-dialog').open){hearing.step=-1;$('hearing-dialog').close();}
    // Last reads stay visible with an explicit stale label; never imply current state after loss.
    $('updated').textContent=lastState?'Last read · disconnected':'No device data read yet';
    if(event.detail.expected)note('The earbuds are restarting their connection…');
    else if(event.detail.reason)note(event.detail.reason);
    connect.disabled=false;
  }
  syncControls();
});
session.addEventListener('reconnecting',()=>note('Waiting for the earbuds to reconnect…'));
session.addEventListener('state',event=>render(event.detail));
session.addEventListener('live',()=>{$('device-status').textContent='Live updates connected';});
session.addEventListener('fieldError',()=>{if(!busy)note('Some values were not reported. You can refresh to check again.');});
session.addEventListener('subscribed',()=>{$('device-status').textContent=session.events?'Live updates connected':'Waiting for live updates';});
connect.onclick=async()=>{
  if(busy)return;busy=true;connect.disabled=true;note('Select OnePlus Buds 4 in the device chooser.');
  try{
    const port=await session.choose();resetUnknown();lastState=null;
    note('Reading your earbuds…');await session.connect(port);
    note(Object.keys(session.state.errors??{}).filter(f=>f!=='golden').length?'Connected. Some values were not reported. Refresh to check again.':'Connected. Change any setting below.');
  }catch(error){note(error.name==='NotFoundError'?'No earbuds selected. Connect when you are ready.':error.message,error.name!=='NotFoundError');}
  finally{busy=false;connect.disabled=false;syncControls();}
};
disconnect.onclick=()=>session.close('Disconnected. You can reconnect whenever you like.');
refresh.onclick=()=>run('Refreshing device state',()=>session.refresh(),'Device state refreshed.');
document.querySelectorAll('.ear-tab').forEach(button=>button.onclick=()=>{
  ear=button.dataset.ear;
  document.querySelectorAll('.ear-tab').forEach(node=>{const selected=node===button;node.classList.toggle('selected',selected);node.setAttribute('aria-pressed',String(selected));});
  renderGestures(lastState??{});syncControls();
});
syncControls();
if(!navigator.serial||!isSecureContext||/Electron|T3Code/.test(navigator.userAgent)){
  connect.disabled=true;note('Open this page in Google Chrome on your Mac to connect your earbuds.');
}
