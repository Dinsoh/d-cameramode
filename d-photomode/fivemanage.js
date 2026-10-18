'use strict';
const https = require('node:https');
const { randomBytes } = require('node:crypto');
const API = 'https://api.fivemanage.com/api/v3/file';
const PUBLIC_HOST = 'r2.fivemanage.com';
function publicUrl(response) {
  if (response?.status !== 'ok' || typeof response.data?.id !== 'string' || !response.data.id.length || response.data.id.length > 512 || /[\u0000-\u001f\u007f]/.test(response.data.id)) throw new Error('Invalid FiveManage response');
  // Use the permanent canonical CDN URL if a custom CDN was returned. No signed,
  // expiring query URLs or client-provided hosts are accepted as printed photos.
  for (const candidate of [response.data.originalUrl, response.data.url]) {
    if (typeof candidate !== 'string') continue;
    let url;
    try { url = new URL(candidate); } catch (_) { continue; }
    if (url.protocol === 'https:' && url.hostname === PUBLIC_HOST && !url.port && !url.username && !url.password && !url.search && !url.hash && /^\/.+\.(jpg|jpeg|png|webp)$/i.test(url.pathname)) {
      return {provider: 'fivemanage', fileId: response.data.id, url: url.href};
    }
  }
  throw new Error('FiveManage returned no permanent supported image URL');
}
function multipart(image, photoId) {
  if (!/^[a-f0-9-]{36}$/.test(photoId)) throw new Error('Invalid photo ID');
  const boundary = `photomode-${randomBytes(18).toString('hex')}`;
  const parts = [];
  for (const [name, value] of Object.entries({filename:`${photoId}.jpg`, path:'d-photomode', retentionExempt:'true', metadata:JSON.stringify({photoId})})) {
    parts.push(Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="${name}"\r\n\r\n${value}\r\n`));
  }
  parts.push(Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="${photoId}.jpg"\r\nContent-Type: image/jpeg\r\n\r\n`), image, Buffer.from(`\r\n--${boundary}--\r\n`));
  return {body:Buffer.concat(parts), contentType:`multipart/form-data; boundary=${boundary}`};
}
function uploadJpeg(image, photoId, apiKey, {request = https.request, signal, timeoutMs = 15000} = {}) {
  if (typeof apiKey !== 'string' || !apiKey.trim() || /[\r\n]/.test(apiKey)) return Promise.reject(new Error('FiveManage media key is not configured'));
  if (!Buffer.isBuffer(image) || image.length < 4 || image.length > 4 * 1024 * 1024 || image[0] !== 255 || image[1] !== 216 || image.at(-2) !== 255 || image.at(-1) !== 217) return Promise.reject(new Error('Invalid JPEG upload'));
  const form = multipart(image, photoId);
  return new Promise((resolve, reject) => {
    // Fixed HTTPS destination, normal TLS checks and no redirects. Never include
    // the token or response body in errors/logs or forward either to a client.
    const req = request(API, {method:'POST', signal, headers:{
      Authorization:apiKey, 'Content-Type':form.contentType, 'Content-Length':String(form.body.length)
    }}, response => {
      const chunks = []; let size = 0;
      response.on('data', chunk => {
        size += chunk.length;
        if (size > 65536) { response.destroy(); reject(new Error('FiveManage response exceeds limit')); return; }
        chunks.push(chunk);
      });
      response.on('error', () => reject(new Error('FiveManage response failed')));
      response.on('aborted', () => reject(new Error('FiveManage response interrupted')));
      response.on('end', () => {
        if (response.statusCode < 200 || response.statusCode >= 300) { reject(new Error(`FiveManage upload rejected (${Number(response.statusCode) || 0})`)); return; }
        try { resolve(publicUrl(JSON.parse(Buffer.concat(chunks).toString('utf8')))); }
        catch (_) { reject(new Error('FiveManage upload result is invalid')); }
      });
    });
    req.setTimeout(timeoutMs, () => req.destroy(new Error('Upload timeout')));
    req.on('error', () => reject(new Error('FiveManage upload connection failed')));
    req.end(form.body);
  });
}
module.exports = {uploadJpeg, publicUrl, multipart};
