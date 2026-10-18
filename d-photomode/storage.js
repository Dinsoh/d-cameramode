'use strict';
// Trusted server exports only. No network event can allocate, finalize or read records.
const path = require('node:path');
const fs = require('node:fs/promises');
const resource = GetCurrentResourceName();
const {PhotoStore, ID} = require(path.join(GetResourcePath(resource), 'storage-core.js'));
let store;
try {
  store = new PhotoStore(path.join(GetResourcePath(resource), 'data', 'photos'), GetConvar('d_photomode_public_base_url', ''));
} catch (_) { console.error('[d-photomode] Invalid d_photomode_public_base_url; photo storage disabled.'); }
const {uploadJpeg} = require(path.join(GetResourcePath(resource), 'fivemanage.js'));
const provider = GetConvar('d_photomode_storage', 'fivemanage');
const capturing = new Set();
const cancellations = new Map();
const maxUploads = Math.max(1, Math.min(16, GetConvarInt('d_photomode_max_uploads', 4)));
exports('capturePhotoToStorage', (player, metadata, callback, progress) => {
  if (typeof callback !== 'function') return;
  const apiKey = GetConvar('d_photomode_fivemanage_key', GetConvar('FIVEMANAGE_MEDIA_API_KEY', ''));
  const configured = provider === 'fivemanage' ? Boolean(apiKey) : provider === 'local' && Boolean(store?.publicBase);
  if (!store || !configured || GetResourceState('screencapture') !== 'started' || capturing.has(player) || capturing.size >= maxUploads) {
    callback('Photo storage is unavailable or a capture is already running', null); return;
  }
  capturing.add(player);
  let allocation, finished = false, processing = false, stage = 'allocate';
  const report = error => {
    const codes = ['EACCES','EPERM','ENOSPC','EROFS','ENOENT','EIO','EINVAL','ENOSYS','ENOTSUP','EEXIST','EBADF'];
    const validation = ['Invalid screenshot size','Invalid screenshot encoding','Image exceeds storage limits','Capture is not a JPEG','Missing server-owned capture identity'];
    const detail = codes.includes(error?.code) ? error.code : validation.includes(error?.message) ? error.message : 'operation failed';
    const reason = typeof error?.message === 'string' && error.message.startsWith('FiveManage') ? error.message : detail;
    console.warn(`[d-photomode] Capture failed at ${stage}: ${reason}${allocation ? ` (photo ${allocation.id})` : ''}.`);
  };
  const controller = new AbortController();
  const complete = (error, photo) => {
    if (finished) return;
    finished = true; clearTimeout(timeout); capturing.delete(player); cancellations.delete(player); callback(error, photo);
  };
  // ScreenCapture's one-use upload token returns bytes to this server only.
  const timeout = setTimeout(() => {
    controller.abort();
    complete('Screenshot timed out', null);
    if (allocation) store.discardUnfinished(allocation.id).catch(() => {});
  }, 40000);
  cancellations.set(player, () => {
    controller.abort(); complete('Capture cancelled', null);
    if (allocation) store.discardUnfinished(allocation.id).catch(() => {});
  });
  store.allocate().then(result => {
    allocation = result;
    if (finished) return;
    stage = 'screenshot';
    global.exports.screencapture.serverCapture(player, {
      // ScreenCapture forwards this to canvas.toBlob; image/jpg falls back to PNG.
      encoding: 'jpeg', quality: 0.85, maxWidth: 1920, maxHeight: 1080
    }, async data => {
      if (processing) return;
      processing = true;
      if (finished) { await store.discardUnfinished(allocation.id).catch(() => {}); return; }
      try {
        stage = 'decode';
        // ScreenCapture returns the data URI through its server callback; bytes only
        // pass between server resources. Write inside our own resource to avoid needing
        // cross-resource filesystem permissions. Our net events carry no image bytes.
        if (typeof data !== 'string' || data.length > Math.ceil(store.maxBytes / 3) * 4 + 64) throw new Error('Invalid screenshot size');
        const match = /^data:image\/(?:jpeg|jpg);base64,([A-Za-z0-9+/]+={0,2})$/.exec(data);
        if (!match) throw new Error('Invalid screenshot encoding');
        stage = 'write-image';
        await fs.writeFile(allocation.fileName, Buffer.from(match[1], 'base64'), {flag:'wx'});
        let hosting;
        stage = 'validate-image';
        const {image} = await store.validateCapture(allocation.id, metadata);
        if (finished) return;
        if (typeof progress === 'function') progress('captured');
        stage = 'upload';
        if (provider === 'fivemanage') hosting = await uploadJpeg(image, allocation.id, apiKey, {signal:controller.signal});
        if (finished) return;
        stage = 'save-record';
        const photo = await store.finalize(allocation.id, metadata, hosting);
        complete(null, photo);
      } catch (error) {
        if (!finished) report(error);
        const message = stage === 'upload' ? 'Image hosting failed. Ask staff to check the server log.' : stage === 'decode' || stage === 'validate-image' ? 'Screenshot format or size is unsupported.' : 'Photo storage failed. Ask staff to check the server log.';
        complete(message, null);
        await store.discardUnfinished(allocation.id).catch(() => {});
      }
    }, 'base64');
  }).catch(error => {
    if (!finished) report(error);
    complete('Capture could not start. Ask staff to check the server log.', null);
  });
});
exports('cancelPhotoCapture', player => cancellations.get(player)?.());
exports('readPhotoRecord', (id, callback) => {
  if (!store || !ID.test(String(id))) { callback('Invalid photo', null); return; }
  store.read(id).then(record => callback(null, record)).catch(() => callback('Photo not found', null));
});
for (const method of ['prepareDelivery','settleDelivery']) exports(method, (id, owner, value, callback) => {
  if (!store || !ID.test(String(id))) { callback('Invalid photo', null); return; }
  store[method](id, owner, value).then(record => callback(null, record)).catch(() => callback('Photo delivery could not be saved', null));
});
exports('readPhotoDelivery', (id, callback) => {
  if (!store || !ID.test(String(id))) { callback('Invalid photo', null); return; }
  store.delivery(id).then(record => callback(null, record)).catch(() => callback('Photo delivery not found', null));
});
exports('readPhotoDisplay', (id, callback) => {
  if (!store || !ID.test(String(id))) { callback('Invalid photo', null); return; }
  store.read(id).then(record => callback(null, store.publicRecord(record))).catch(() => callback('Photo not found', null));
});
SetHttpHandler((request, response) => {
  const match = /^\/photos\/([a-f0-9-]+)\.jpg$/.exec(request.path || '');
  if (!store || provider !== 'local' || !store.publicBase || request.method !== 'GET' || !match || !ID.test(match[1])) {
    response.writeHead(404, {'Content-Type':'text/plain'}); response.send('Not found'); return;
  }
  store.image(match[1]).then(image => {
    response.writeHead(200, {'Content-Type':'image/jpeg','Content-Length':String(image.length),
      'Cache-Control':'public, max-age=31536000, immutable','X-Content-Type-Options':'nosniff'});
    response.send(image);
  }).catch(() => { response.writeHead(404, {'Content-Type':'text/plain'}); response.send('Not found'); });
});
