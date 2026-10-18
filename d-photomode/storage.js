'use strict';
// Trusted server exports only. No network event can allocate, finalize or read records.
// QS item/film transactions are intentionally not registered until its installed API is verified.
const fs = require('node:fs/promises');
const path = require('node:path');
const resource = GetCurrentResourceName();
const {PhotoStore, ID} = require(path.join(GetResourcePath(resource), 'storage-core.js'));
let store;
try {
  store = new PhotoStore(path.join(GetResourcePath(resource), 'data', 'photos'), GetConvar('d_photomode_public_base_url', ''));
} catch (_) { console.error('[d-photomode] Invalid d_photomode_public_base_url; photo storage disabled.'); }
const capturing = new Set();
exports('capturePhotoToStorage', (player, metadata, callback) => {
  if (typeof callback !== 'function') return;
  if (!store || !store.publicBase || GetResourceState('screenshot-basic') !== 'started' || capturing.has(player)) {
    callback('Photo storage is unavailable or a capture is already running', null); return;
  }
  capturing.add(player);
  let allocation, finished = false;
  const complete = (error, photo) => {
    if (finished) return;
    finished = true; clearTimeout(timeout); capturing.delete(player); callback(error, photo);
  };
  // HTTP uploads use screenshot-basic's one-use token, not ordinary gameplay events.
  const timeout = setTimeout(() => {
    complete('Screenshot timed out', null);
    if (allocation) store.discardUnfinished(allocation.id).catch(() => {});
  }, 20000);
  store.allocate().then(result => {
    allocation = result;
    if (finished) return;
    global.exports['screenshot-basic'].requestClientScreenshot(player, {
      fileName: allocation.fileName, encoding: 'jpg', quality: 0.85
    }, async error => {
      if (finished) { await store.discardUnfinished(allocation.id).catch(() => {}); return; }
      if (error) { complete('Screenshot upload failed', null); await store.discardUnfinished(allocation.id).catch(() => {}); return; }
      try {
        const photo = await store.finalize(allocation.id, metadata);
        complete(null, photo);
      } catch (_) {
        complete('Capture could not be stored', null);
        await store.discardUnfinished(allocation.id).catch(() => {});
      }
    });
  }).catch(() => complete('Capture could not start', null));
});
exports('readPhotoRecord', (id, callback) => {
  if (!store || !ID.test(String(id))) { callback('Invalid photo', null); return; }
  store.read(id).then(record => callback(null, record)).catch(() => callback('Photo not found', null));
});
SetHttpHandler((request, response) => {
  const match = /^\/photos\/([a-f0-9-]+)\.jpg$/.exec(request.path || '');
  if (!store || !store.publicBase || request.method !== 'GET' || !match || !ID.test(match[1])) {
    response.writeHead(404, {'Content-Type':'text/plain'}); response.send('Not found'); return;
  }
  store.image(match[1]).then(image => {
    response.writeHead(200, {'Content-Type':'image/jpeg','Content-Length':String(image.length),
      'Cache-Control':'public, max-age=31536000, immutable','X-Content-Type-Options':'nosniff'});
    response.send(image);
  }).catch(() => { response.writeHead(404, {'Content-Type':'text/plain'}); response.send('Not found'); });
});
