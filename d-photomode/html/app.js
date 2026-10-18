const $ = id => document.getElementById(id);
let active = false;
let hideKey = 'H';
let orbit = false;
let timer;
let dirty = false;
let inFlight = null;
let captureRequested = false;
let captureKey = 'RETURN';
let captureStatusTimer;
async function post(route, data = {}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 2500);
  try {
    const response = await fetch(`https://${GetParentResourceName()}/${route}`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data), signal: controller.signal
    });
    if (!response.ok) throw new Error('Request failed');
    const result = await response.json();
    $('error').hidden = result.ok !== false;
    return result;
  } catch (_) { $('error').hidden = false; return { ok: false }; }
  finally { clearTimeout(timeout); }
}
function values() {
  return { fov: Number($('fov').value), tilt: Number($('tilt').value),
    angle: Number($('angle').value), distance: Number($('distance').value), height: Number($('height').value),
    filter: Number($('filter').value), strength: Number($('strength').value), dofStrength: Number($('dofStrength').value), dof: $('dof').checked, focus: Number($('focus').value) };
}
function labels() {
  $('strengthValue').textContent = `${Math.round(Number($('strength').value) * 100)}%`;
  $('strength').disabled = $('filter').value === '1';
  $('dofStrengthValue').textContent = `${Math.round(Number($('dofStrength').value) * 100)}%`;
  $('angleValue').textContent = `${$('angle').value}°`;
  $('distanceValue').textContent = `${Number($('distance').value).toFixed(2)} m`;
  $('heightValue').textContent = `${Number($('height').value).toFixed(2)} m`;
  $('fovValue').textContent = `${$('fov').value}°`;
  $('tiltValue').textContent = `${$('tilt').value}°`;
  $('focusValue').textContent = `${$('focus').value} m`;
}
async function flush() {
  if (!active) return {ok:false};
  if (inFlight) {
    const previous = await inFlight;
    return dirty && active ? flush() : previous;
  }
  dirty = false;
  inFlight = post('update', values());
  const result = await inFlight;
  inFlight = null;
  return dirty && active ? flush() : result;
}
function update() {
  if (captureRequested) return;
  labels(); dirty = true;
  if (!timer) timer = setTimeout(() => { timer = undefined; flush(); }, 50);
}
function reset() {
  $('angle').value = 0;
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
    active = true; hideKey = data.hideKey;
    captureKey = data.captureKey || 'RETURN'; captureRequested = false;
    $('capture').disabled = false;
    $('caption').value = ''; $('caption').maxLength = data.captionLength ?? 80;
    $('captionControl').hidden = (data.captionLength ?? 80) === 0;
    $('captureMessage').textContent = ''; hideCaptureStatus();
    orbit = data.orbit || false;
    $('orbit').hidden = !orbit;
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
    $('hint').textContent = `${captureKey} · shutter / ${hideKey} · hide overlay / Escape · exit`;
    reset(); selectTab('camera');
  } else if (data.action === 'close') {
    active = false; captureRequested = false; hideCaptureStatus(); $('captureFlash').hidden = true; clearTimeout(timer); timer = undefined; $('frame').hidden = true;
  } else if (data.action === 'prepareCapture') {
    captureRequested = true; $('capture').disabled = true;
    $('frame').hidden = true; hideCaptureStatus(); $('captureFlash').hidden = true;
    // Give CEF two painted frames without overlays/cursor before authorizing capture.
    requestAnimationFrame(() => requestAnimationFrame(() => {
      if (active && captureRequested) post('captureReady', {id:data.id});
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
  } else if (data.action === 'hidden') {
    $('frame').hidden = data.hidden; // hide guides and bars too for a completely clean screenshot
  }
});
for (const id of ['fov', 'tilt', 'filter', 'dof', 'focus', 'angle', 'distance', 'height', 'strength', 'dofStrength']) $(id).addEventListener('input', update);
$('showGrid').addEventListener('change', () => { $('grid').hidden = !$('showGrid').checked; });
$('showBars').addEventListener('change', () => { $('bars').hidden = !$('showBars').checked; });
$('close').addEventListener('click', () => post('close'));
$('hide').addEventListener('click', () => { if (!captureRequested) post('hide'); });
$('reset').addEventListener('click', () => { if (!captureRequested) { reset(); update(); } });
window.addEventListener('keydown', event => {
  if (!active || event.repeat) return;
  if ((event.key === 'Enter' && captureKey === 'RETURN') || event.key.toUpperCase() === captureKey) { event.preventDefault(); takePhotograph(); }
  if (event.key === 'Escape') { event.preventDefault(); post('close'); }
  // When focused NUI owns keyboard events; game key mapping handles the hidden state.
  if (event.key.toUpperCase() === hideKey.toUpperCase()) { event.preventDefault(); post('hide'); }
});

for (const button of document.querySelectorAll('[data-angle]')) button.addEventListener('click', () => { $('angle').value = button.dataset.angle; update(); });

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
  const applied = await flush();
  if (!active) return;
  if (!applied?.ok) { captureRequested = false; $('capture').disabled = false; return; }
  const result = await post('capture', {caption:$('caption').value});
  if (!result.ok && active) { captureRequested = false; $('capture').disabled = false; }
}
$('capture').addEventListener('click', takePhotograph);
$('captureFlash').addEventListener('animationend', () => { $('captureFlash').hidden = true; });
