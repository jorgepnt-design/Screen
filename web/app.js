'use strict';
const $ = id => document.getElementById(id);
let lock = null, generation = 0, busy = false, started = 0, deadline = 0, timer = null;
const allowed = [0,15,30,60,120,240];
try { const saved = Number(localStorage.getItem('screenOnMinutes')); if (allowed.includes(saved)) $('duration').value = String(saved); } catch {}
const supported = 'wakeLock' in navigator && window.isSecureContext;
function active() { return !!lock && !lock.released; }
function updateTime() {
  if (!active()) return;
  if (deadline && performance.now() >= deadline) { void stop('Der Abschalttimer ist abgelaufen.'); return; }
  const n = Math.max(0, Math.floor((performance.now() - started)/1000));
  $('time').textContent = 'Aktiv seit ' + [Math.floor(n/3600), Math.floor(n/60)%60,n%60].map(x=>String(x).padStart(2,'0')).join(':');
}
function render() {
  const on = active();
  document.body.classList.toggle('active',on);
  $('status').innerHTML = '<span></span> ' + (on?'AKTIV':'AUS');
  $('message').textContent = on?'Bildschirm bleibt eingeschaltet':'Automatische Bildschirmsperre ist aktiv';
  $('button-label').textContent = on?'Bildschirm wieder automatisch ausschalten':'Bildschirm anlassen';
  $('button-hint').textContent = busy?'Einen Moment …':on?'Einmal tippen zum Ausschalten':'Einmal tippen zum Einschalten';
  $('toggle').setAttribute('aria-pressed',String(on));
  $('toggle').disabled = busy || !supported;
  if (!on) $('time').textContent = 'Bereit, wenn du es bist.';
  else updateTime();
  document.title = on?'ON · Screen On':'Screen On';
}
function clearTimer(){ clearInterval(timer); timer=null; }
async function start() {
  if (busy || active() || !supported || document.visibilityState !== 'visible') return;
  const id = ++generation;
  busy=true; $('notice').textContent=''; render();
  try {
    const acquired = await navigator.wakeLock.request('screen');
    if (id !== generation || document.visibilityState !== 'visible') { await acquired.release(); return; }
    if (acquired.released) throw new Error('released');
    lock=acquired; started=performance.now();
    const minutes=Number($('duration').value);
    deadline=minutes?started+minutes*60000:0;
    acquired.addEventListener('release',()=>{
      if (lock !== acquired) return;
      lock=null; ++generation; clearTimer();
      $('notice').textContent='Screen On wurde von iOS oder dem Browser beendet. Zum Fortsetzen erneut einschalten.';
      render();
    },{once:true});
    timer=setInterval(updateTime,250);
  } catch {
    if(id===generation) $('notice').textContent='Der Bildschirm konnte nicht wach gehalten werden. Öffne die App in Safari, prüfe den Stromsparmodus und versuche es erneut.';
  } finally { if(id===generation){busy=false;render();} }
}
async function stop(message='') {
  ++generation;
  const previous=lock;
  busy=!!previous;
  clearTimer();
  if(previous && !previous.released) {
    try { await previous.release(); }
    catch {
      // Keep the actual lock represented; never claim OFF after a failed release.
      busy=false;
      $('notice').textContent='Ausschalten wurde nicht bestätigt. Bitte erneut tippen oder die App verlassen.';
      if(active()) timer=setInterval(updateTime,250);
      render(); return;
    }
  }
  if(lock===previous) lock=null;
  busy=false; $('notice').textContent=message; render();
}
$('toggle').addEventListener('click',()=>{ if(active()) void stop(); else void start(); });
function showSettings(){ $('timer-dialog').showModal(); }
$('settings').addEventListener('click',showSettings);
$('timer-shortcut').addEventListener('click',showSettings);
function durationChanged(){ $('timer-shortcut').textContent=$('duration').selectedOptions[0].textContent; }
$('duration').addEventListener('change',()=>{ if(!allowed.includes(Number($('duration').value))) $('duration').value='0'; try {localStorage.setItem('screenOnMinutes',$('duration').value);}catch{} durationChanged(); });
document.addEventListener('visibilitychange',()=>{ if(document.visibilityState!=='visible') void stop('Beim Verlassen der App wird Screen On ausgeschaltet.'); });
window.addEventListener('pagehide',()=>{void stop();});
window.addEventListener('pageshow',()=>{ if(!active()){busy=false;render();} });
if(!supported) $('notice').textContent='Dieser Browser unterstützt das Wachhalten nicht. Bitte in einer aktuellen Safari-Version öffnen.';
if(window.matchMedia('(display-mode: standalone)').matches || navigator.standalone) $('install').hidden=true;
durationChanged();render();
if('serviceWorker' in navigator) navigator.serviceWorker.register('./sw.js').catch(()=>{});
// Optional agent integration; uses the same stop action and confirmed state.
if(document.modelContext?.registerTool){
  for(const tool of [
    {name:'get_screen_status',description:'Read the actual screen wake lock status.',inputSchema:{type:'object',properties:{},additionalProperties:false},annotations:{readOnlyHint:true},execute:()=>({active:active(),supported})},
    {name:'stop_screen_on',description:'Release the current screen wake lock.',inputSchema:{type:'object',properties:{},additionalProperties:false},annotations:{readOnlyHint:false},execute:async()=>{await stop();return {active:active()};}}
  ]) {try{Promise.resolve(document.modelContext.registerTool(tool)).catch(()=>{});}catch{}}
}
