const $ = id => document.getElementById(id);
let active = false;
let hideKey = 'H';
let orbit = false;
let timer;
let sending = false;
let dirty = false;
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
    filter: Number($('filter').value), dof: $('dof').checked, focus: Number($('focus').value) };
}
function labels() {
  $('angleValue').textContent = `${$('angle').value}°`;
  $('distanceValue').textContent = `${Number($('distance').value).toFixed(2)} m`;
  $('heightValue').textContent = `${Number($('height').value).toFixed(2)} m`;
  $('fovValue').textContent = `${$('fov').value}°`;
  $('tiltValue').textContent = `${$('tilt').value}°`;
  $('focusValue').textContent = `${$('focus').value} m`;
}
async function flush() {
  if (sending || !active) return;
  sending = true; dirty = false;
  await post('update', values());
  sending = false;
  if (dirty && active) flush();
}
function update() {
  labels(); dirty = true;
  if (!timer) timer = setTimeout(() => { timer = undefined; flush(); }, 50);
}
function reset() {
  $('angle').value = 0;
  if (orbit) { $('distance').value = orbit.distance.default; $('height').value = orbit.height.default; }
  $('fov').value = $('fov').dataset.default;
  $('tilt').value = 0; $('filter').value = 1;
  $('dof').checked = false; $('focus').value = 5;
  $('showGrid').checked = false; $('showBars').checked = false;
  $('grid').hidden = true; $('bars').hidden = true;
  labels();
}
window.addEventListener('message', ({ data }) => {
  if (!data || typeof data.action !== 'string') return;
  if (data.action === 'open') {
    active = true; hideKey = data.hideKey;
    orbit = data.orbit || false;
    $('orbit').hidden = !orbit;
    if (orbit) {
      for (const id of ['distance', 'height']) { $(id).min = orbit[id].min; $(id).max = orbit[id].max; }
    }
    $('frame').hidden = false; $('panel').hidden = false; $('error').hidden = true;
    $('fov').min = data.fov.min; $('fov').max = data.fov.max; $('fov').dataset.default = data.fov.default;
    $('tilt').min = -data.tilt; $('tilt').max = data.tilt;
    $('filter').replaceChildren(...data.filters.map((item, index) => {
      const option = document.createElement('option'); option.value = index + 1;
      option.textContent = item.label; return option;
    }));
    $('depth').hidden = !data.dof;
    $('hint').textContent = `Escape · exit / ${hideKey} · hide or restore overlay. Use your usual screenshot key.`;
    reset();
  } else if (data.action === 'close') {
    active = false; clearTimeout(timer); timer = undefined; $('frame').hidden = true;
  } else if (data.action === 'hidden') {
    $('frame').hidden = data.hidden; // hide guides and bars too for a completely clean screenshot
  }
});
for (const id of ['fov', 'tilt', 'filter', 'dof', 'focus', 'angle', 'distance', 'height']) $(id).addEventListener('input', update);
$('showGrid').addEventListener('change', () => { $('grid').hidden = !$('showGrid').checked; });
$('showBars').addEventListener('change', () => { $('bars').hidden = !$('showBars').checked; });
$('close').addEventListener('click', () => post('close'));
$('hide').addEventListener('click', () => post('hide'));
$('reset').addEventListener('click', () => { reset(); update(); });
window.addEventListener('keydown', event => {
  if (!active || event.repeat) return;
  if (event.key === 'Escape') { event.preventDefault(); post('close'); }
  // When focused NUI owns keyboard events; game key mapping handles the hidden state.
  if (event.key.toUpperCase() === hideKey.toUpperCase()) { event.preventDefault(); post('hide'); }
});

for (const button of document.querySelectorAll('[data-angle]')) button.addEventListener('click', () => { $('angle').value = button.dataset.angle; update(); });
