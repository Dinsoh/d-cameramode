const $ = id => document.getElementById(id);
let active = false;
let viewfinder = false;
let settingsOpen = true;
let hideKey = 'H';
let orbit = false;
let timer;
let pendingChanges = {};
let generation = 0;
let session;
let inFlight = null;
let captureRequested = false;
let captureKey = 'RETURN';
let captureStatusTimer;
async function post(route, data = {}, version = generation) {
  data = {...data, session};
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 2500);
  try {
    const response = await fetch(`https://${GetParentResourceName()}/${route}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data), signal: controller.signal
    });
    if (!response.ok) throw new Error('Request failed');
    const result = await response.json();
    if (active && version === generation) $('error').hidden = result.ok !== false;
    return result;
  } catch (_) { if (active && version === generation) $('error').hidden = false; return { ok: false }; }
  finally { clearTimeout(timeout); }
}
function values() {
  return { mode:$('cameraMode').value, pose:$('cameraPose').checked, fov: Number($('fov').value), tilt: Number($('tilt').value),
    angle: Number($('angle').value), distance: Number($('distance').value), height: Number($('height').value),
    filter: Number($('filter').value), strength: Number($('strength').value), dofStrength: Number($('dofStrength').value), dof: $('dof').checked, focus: Number($('focus').value) };
}
function labels() {
  $('strengthValue').textContent = `${Math.round(Number($('strength').value) * 100)}%`;
  $('strength').disabled = $('filter').value === '1';
  $('dofStrengthValue').textContent = `${Math.round(Number($('dofStrength').value) * 100)}%`;
  $('angleValue').textContent = `${Number($('angle').value).toFixed(1)}°`;
  $('distanceValue').textContent = `${Number($('distance').value).toFixed(2)} m`;
  $('heightValue').textContent = `${Number($('height').value).toFixed(2)} m`;
  $('fovValue').textContent = `${$('fov').value}°`;
  $('lensValue').textContent = `${(Math.tan(Number($('fov').dataset.default || 70) * Math.PI / 360) / Math.tan(Number($('fov').value) * Math.PI / 360)).toFixed(1)}×`;
  $('tiltValue').textContent = `${Number($('tilt').value).toFixed(1)}°`;
  $('focusValue').textContent = `${$('focus').value} m`;
}
async function flush() {
  if (!active) return {ok:false};
  const version = generation;
  if (inFlight) {
    const previous = await inFlight.promise;
    if (!active || version !== generation) return {ok:false};
    return Object.keys(pendingChanges).length ? flush() : previous;
  }
  if (!Object.keys(pendingChanges).length) return {ok:true};
  const patch = pendingChanges; pendingChanges = {};
  const current = {promise:post('update', patch, version)};
  inFlight = current;
  const result = await current.promise;
  if (inFlight === current) inFlight = null;
  if (!active || version !== generation) return {ok:false};
  if (!result.ok) { pendingChanges = {...patch, ...pendingChanges}; return result; }
  return Object.keys(pendingChanges).length ? flush() : result;
}
const controlKeys = {cameraMode:'mode', cameraPose:'pose'};
function update(event) {
  if (captureRequested) return;
  $('orbit').hidden = !orbit || (viewfinder && $('cameraMode').value !== 'selfie');
  labels();
  const current = values();
  if (event?.target) {
    const key = controlKeys[event.target.id] || event.target.id;
    pendingChanges[key] = current[key];
  } else pendingChanges = {...pendingChanges, ...current}; // explicit Reset only
  if (!timer) timer = setTimeout(() => { timer = undefined; flush(); }, 50);
}
async function returnToCamera() {
  if (captureRequested) return;
  clearTimeout(timer); timer = undefined;
  const version = generation;
  const result = await flush();
  if (active && version === generation && result.ok) post('hide');
}
function reset() {
  $('angle').value = 0; $('cameraPose').checked = true;
  if (orbit) { $('distance').value = orbit.distance.default; $('height').value = orbit.height.default; }
  $('fov').value = $('fov').dataset.default;
  $('tilt').value = 0; $('filter').value = 1;
  $('dof').checked = false; $('focus').value = 5;
  $('strength').value = $('strength').dataset.default; $('dofStrength').value = 0.5;
  $('guide').value = 'thirds'; $('ratio').value = '2.39'; composition();
  $('showGrid').checked = false; $('showBars').checked = false;
  $('grid').hidden = true; $('bars').hidden = true;
  labels();
}
window.addEventListener('message', ({ data }) => {
  if (!data || typeof data.action !== 'string') return;
  if (data.action === 'open') {
    generation++; session = data.session;
    clearTimeout(timer); timer = undefined; pendingChanges = {}; inFlight = null;
    active = true; hideKey = data.hideKey;
    viewfinder = Boolean(data.viewfinder); settingsOpen = !viewfinder;
    captureKey = data.captureKey || 'RETURN'; captureRequested = false;
    $('capture').disabled = false;
    $('caption').value = ''; $('caption').maxLength = data.captionLength ?? 80;
    $('captionControl').hidden = (data.captionLength ?? 80) === 0;
    $('captureMessage').textContent = ''; hideCaptureStatus();
    orbit = data.orbit || false;
    $('cameraMode').value = viewfinder ? 'camera' : 'selfie';
    $('viewControl').hidden = !viewfinder || !orbit;
    $('orbit').hidden = !orbit || viewfinder;
    if (orbit) {
      for (const id of ['distance', 'height']) { $(id).min = orbit[id].min; $(id).max = orbit[id].max; }
    }
    $('frame').hidden = false; $('panel').hidden = false; $('error').hidden = true;
    $('strength').dataset.default = data.strength ?? 0.65;
    $('fov').min = data.fov.min; $('fov').max = data.fov.max; $('fov').dataset.default = data.fov.default;
    $('tilt').min = -data.tilt; $('tilt').max = data.tilt;
    $('filter').replaceChildren(...data.filters.map((item, index) => {
      const option = document.createElement('option'); option.value = index + 1;
      option.textContent = item.label; return option;
    }));
    $('depth').hidden = !data.dof;
    $('hint').textContent = `${captureKey} · shutter / ${hideKey} · ${viewfinder ? 'settings' : 'hide overlay'} / Escape · exit`;
    reset(); selectTab('camera');
    $('panel').hidden = !settingsOpen; $('viewfinderHud').hidden = !viewfinder;
    labels();
    $('viewfinderHint').textContent = `${captureKey} · shutter   /   Scroll · zoom   /   ${hideKey} · settings   /   Escape · exit`;
    $('hide').textContent = viewfinder ? 'Back to camera' : 'Hide overlay';
  } else if (data.action === 'close') {
    generation++; pendingChanges = {}; inFlight = null;
    active = false; captureRequested = false; hideCaptureStatus(); $('captureFlash').hidden = true; clearTimeout(timer); timer = undefined; $('frame').hidden = true;
  } else if (data.action === 'prepareCapture') {
    captureRequested = true; $('capture').disabled = true;
    $('frame').hidden = true; hideCaptureStatus(); $('captureFlash').hidden = true;
    const version = generation;
    // Give CEF two painted frames without overlays/cursor before authorizing capture.
    requestAnimationFrame(() => requestAnimationFrame(() => {
      if (active && captureRequested && version === generation) post('captureReady', {id:data.id});
    }));
  } else if (data.action === 'captured') {
    $('captureFlash').hidden = false;
    status('Uploading photograph…', false);
  } else if (data.action === 'printing') {
    status('Printing photograph…', true);
  } else if (data.action === 'captureResult') {
    captureRequested = false; $('capture').disabled = false;
    $('frame').hidden = Boolean(data.hidden);
    $('captureMessage').textContent = String(data.message || (data.ok ? 'Photograph printed.' : 'Photograph could not be printed.'));
    status($('captureMessage').textContent, false);
    clearTimeout(captureStatusTimer);
    captureStatusTimer = setTimeout(hideCaptureStatus, 4500);
  } else if (data.action === 'requestCapture') {
    takePhotograph();
  } else if (data.action === 'settings') {
    settingsOpen = Boolean(data.open); $('panel').hidden = !settingsOpen;
  } else if (data.action === 'framing') {
    for (const id of ['fov','tilt','angle','distance','height']) if (Number.isFinite(data[id])) $(id).value = data[id];
    labels();
  } else if (data.action === 'orbitPosition') {
    $('angle').value = data.angle; $('height').value = data.height; labels();
  } else if (data.action === 'lens') {
    $('fov').value = data.fov; labels();
  } else if (data.action === 'hidden') {
    $('frame').hidden = data.hidden; // hide guides and bars too for a completely clean screenshot
  }
});
for (const id of ['cameraMode', 'cameraPose', 'fov', 'tilt', 'filter', 'dof', 'focus', 'angle', 'distance', 'height', 'strength', 'dofStrength']) $(id).addEventListener('input', update);
$('showGrid').addEventListener('change', () => { $('grid').hidden = !$('showGrid').checked; });
$('showBars').addEventListener('change', () => { $('bars').hidden = !$('showBars').checked; });
$('close').addEventListener('click', () => post('close'));
$('hide').addEventListener('click', returnToCamera);
$('reset').addEventListener('click', () => { if (!captureRequested) { reset(); update(); } });
window.addEventListener('keydown', event => {
  if (!active || event.repeat) return;
  if (event.key !== 'Escape' && (event.target.matches('input[type=text], textarea') || event.target.isContentEditable)) return;
  if ((event.key === 'Enter' && captureKey === 'RETURN') || event.key.toUpperCase() === captureKey) { event.preventDefault(); takePhotograph(); }
  if (event.key === 'Escape') { event.preventDefault(); post('close'); }
  // When focused NUI owns keyboard events; game key mapping handles the hidden state.
  if (event.key.toUpperCase() === hideKey.toUpperCase()) { event.preventDefault(); returnToCamera(); }
});

for (const button of document.querySelectorAll('[data-angle]')) button.addEventListener('click', () => { $('angle').value = button.dataset.angle; update({target:$('angle')}); });

function composition() {
  $('grid').dataset.guide = $('guide').value;
  const ratio = Number($('ratio').value);
  const width = window.innerWidth, height = window.innerHeight;
  const frameWidth = Math.min(width, height * ratio), frameHeight = Math.min(height, width / ratio);
  $('bars').style.borderTopWidth = $('bars').style.borderBottomWidth = `${(height - frameHeight) / 2}px`;
  $('bars').style.borderLeftWidth = $('bars').style.borderRightWidth = `${(width - frameWidth) / 2}px`;
}
for (const id of ['guide','ratio']) $(id).addEventListener('change', composition);
window.addEventListener('resize', composition);
function selectTab(name) {
  for (const tab of document.querySelectorAll('[data-tab]')) {
    const selected = tab.dataset.tab === name;
    tab.setAttribute('aria-selected', String(selected));
    $(`${tab.dataset.tab}Settings`).hidden = !selected;
  }
}
for (const tab of document.querySelectorAll('[data-tab]')) tab.addEventListener('click', () => selectTab(tab.dataset.tab));

function hideCaptureStatus() {
  clearTimeout(captureStatusTimer);
  $('captureStatus').hidden = true;
  $('captureStatus').classList.remove('printing');
}
function status(message, printing) {
  clearTimeout(captureStatusTimer);
  $('captureStatus').hidden = false;
  $('captureStatus').classList.toggle('printing', printing);
  $('captureStatus').querySelector('span').textContent = message;
}
async function takePhotograph() {
  if (!active || captureRequested) return;
  captureRequested = true; $('capture').disabled = true;
  clearTimeout(timer); timer = undefined;
  const version = generation;
  const applied = await flush();
  if (!active || version !== generation) return;
  if (!applied?.ok) { captureRequested = false; $('capture').disabled = false; return; }
  const result = await post('capture', {caption:$('caption').value});
  if (!result.ok && active && version === generation) { captureRequested = false; $('capture').disabled = false; }
}
$('capture').addEventListener('click', takePhotograph);
$('captureFlash').addEventListener('animationend', () => { $('captureFlash').hidden = true; });
