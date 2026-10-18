'use strict';
const fs = require('node:fs/promises');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
const ID = /^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/;
class PhotoStore {
  constructor(directory, publicBase, maxBytes = 4 * 1024 * 1024) {
    this.directory = directory; this.maxBytes = maxBytes;
    this.publicBase = publicBase ? new URL(publicBase) : null;
    if (this.publicBase && (this.publicBase.protocol !== 'https:' || this.publicBase.username || this.publicBase.password || this.publicBase.search || this.publicBase.hash)) throw new Error('Public image base must be a permanent HTTPS directory URL');
    if (this.publicBase && !this.publicBase.pathname.endsWith('/')) throw new Error('Public image base must end with /');
  }
  file(id, extension) {
    if (!ID.test(id)) throw new Error('Invalid photo ID');
    return path.join(this.directory, `${id}.${extension}`);
  }
  async allocate() {
    await fs.mkdir(this.directory, {recursive: true});
    const id = randomUUID();
    return {id, fileName: this.file(id, 'jpg')};
  }
  async finalize(id, metadata) {
    const imagePath = this.file(id, 'jpg');
    const stat = await fs.stat(imagePath);
    if (stat.size < 4 || stat.size > this.maxBytes) throw new Error('Image exceeds storage limits');
    const image = await fs.readFile(imagePath);
    if (image[0] !== 255 || image[1] !== 216 || image.at(-2) !== 255 || image.at(-1) !== 217) throw new Error('Capture is not a JPEG');
    if (!metadata || typeof metadata.owner !== 'string' || !metadata.owner || typeof metadata.photographer !== 'string') throw new Error('Missing server-owned capture identity');
    const record = {id, status: 'captured', owner: metadata.owner, photographer: metadata.photographer.slice(0,100), caption: String(metadata.caption || '').slice(0,120), takenAt: new Date().toISOString(), bytes: stat.size};
    // Per-photo, immutable records. An exclusive link publishes a fully written record
    // without replacing an existing photo; sync both files before reporting success.
    const temporary = this.file(id, 'json.tmp');
    const fd = await fs.open(temporary, 'wx', 0o600);
    try { await fd.writeFile(JSON.stringify(record)); await fd.sync(); } finally { await fd.close(); }
    try { await fs.link(temporary, this.file(id, 'json')); } finally { await fs.unlink(temporary).catch(() => {}); }
    const imageHandle = await fs.open(imagePath, 'r');
    try { await imageHandle.sync(); } finally { await imageHandle.close(); }
    const directoryHandle = await fs.open(this.directory, 'r');
    try { await directoryHandle.sync(); } finally { await directoryHandle.close(); }
    return this.publicRecord(record);
  }
  async read(id) {
    const record = JSON.parse(await fs.readFile(this.file(id, 'json'), 'utf8'));
    if (record.id !== id) throw new Error('Photo record identity mismatch');
    return record;
  }
  publicRecord(record) {
    return {id: record.id, photographer: record.photographer, caption: record.caption, takenAt: record.takenAt,
      public: Boolean(this.publicBase), url: this.publicBase ? new URL(`${record.id}.jpg`, this.publicBase).href : null};
  }
  async image(id) { await this.read(id); return fs.readFile(this.file(id, 'jpg')); }
  async discardUnfinished(id) {
    // Never remove an already finalized record on a late or duplicate callback.
    try { await fs.access(this.file(id, 'json')); return; } catch (error) { if (error.code !== 'ENOENT') throw error; }
    await fs.unlink(this.file(id, 'jpg')).catch(error => { if (error.code !== 'ENOENT') throw error; });
  }
}
module.exports = {PhotoStore, ID};
