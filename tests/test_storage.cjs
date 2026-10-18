'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const {PhotoStore} = require('../d-photomode/storage-core.js');
const metadata = {owner:'private-citizen-id',photographer:'Test Player',caption:'Test photograph'};
async function fixture(fn) {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(),'photo-test-'));
  try { await fn(new PhotoStore(directory,'https://photos.example.test/d-photomode/photos/'),directory); }
  finally { await fs.rm(directory,{recursive:true,force:true}); }
}
test('durable record survives a fresh store; public metadata excludes owner',async()=>fixture(async(store,directory)=>{
  const item = await store.allocate();
  await fs.writeFile(item.fileName,Buffer.from([255,216,1,2,255,217]));
  const photo = await store.finalize(item.id,metadata);
  assert.equal(photo.url,`https://photos.example.test/d-photomode/photos/${item.id}.jpg`);
  assert.equal(photo.owner,undefined);
  const restored = new PhotoStore(directory,'https://photos.example.test/d-photomode/photos/');
  assert.equal((await restored.read(item.id)).owner,metadata.owner);
  assert.deepEqual(await restored.image(item.id),Buffer.from([255,216,1,2,255,217]));
  await assert.rejects(store.finalize(item.id,metadata));
  await store.discardUnfinished(item.id);
  assert.equal((await restored.image(item.id)).length,6);
}));
test('reject traversal and invalid public URLs',()=>{
  const store = new PhotoStore('/tmp/unused','https://photos.example.test/');
  assert.throws(()=>store.file('../../secret','jpg'));
  for(const url of ['http://host/','https://user:secret@host/','https://host/path?token=secret','https://host/path']) assert.throws(()=>new PhotoStore('/tmp/unused',url));
});
test('unfinalized files cannot be served; failed formats create no record',async()=>fixture(async(store)=>{
  const item = await store.allocate(); await fs.writeFile(item.fileName,'not-a-photo');
  await assert.rejects(store.finalize(item.id,metadata));
  await assert.rejects(store.image(item.id));
  await store.discardUnfinished(item.id); await assert.rejects(fs.access(item.fileName));
}));
test('oversized images are rejected',async()=>fixture(async(store)=>{
  const item=await store.allocate(); await fs.writeFile(item.fileName,Buffer.alloc(store.maxBytes+1));
  await assert.rejects(store.finalize(item.id,metadata));
}));
