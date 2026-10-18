'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const {EventEmitter} = require('node:events');
const {uploadJpeg, publicUrl} = require('../d-photomode/fivemanage.js');
const fs = require('node:fs/promises');
const path = require('node:path');
const os = require('node:os');
const {PhotoStore} = require('../d-photomode/storage-core.js');
const id = '12345678-1234-4234-8234-123456789abc';
const image = Buffer.from([255,216,1,2,255,217]);
const payload = {status:'ok',data:{id:'media_123',url:'https://r2.fivemanage.com/team/media_123.webp'}};
function transport(status, body, inspect=()=>{}) {
  return (url,options,cb)=>{
    const req = new EventEmitter();
    req.setTimeout=()=>{};
    req.destroy=error=>req.emit('error',error);
    req.end=data=>queueMicrotask(()=>{
      inspect(url,options,data);
      const response=new EventEmitter(); response.statusCode=status; response.destroy=()=>{};
      cb(response); response.emit('data',Buffer.from(body)); response.emit('end');
    });
    return req;
  };
}
test('official V3 multipart route, server auth header, retention exemption and verified URL',async()=>{
  const photo = await uploadJpeg(image,id,'test-only-key',{request:transport(200,JSON.stringify(payload),(url,options,body)=>{
    assert.equal(url,'https://api.fivemanage.com/api/v3/file');
    assert.equal(options.headers.Authorization,'test-only-key');
    assert.match(options.headers['Content-Type'],/^multipart\/form-data; boundary=/);
    assert.ok(body.includes(image));
    assert.match(body.toString(),/name="retentionExempt"\r\n\r\ntrue/);
    assert.match(body.toString(),/name="file"; filename=/);
    assert.ok(!body.includes(Buffer.from('test-only-key')));
  })});
  assert.deepEqual(photo,{provider:'fivemanage',fileId:'media_123',url:payload.data.url});
});
test('reject unsafe/expiring URLs and malformed completion even on HTTP success',async()=>{
  for(const url of ['http://r2.fivemanage.com/t/photo.jpg','https://evil.example/photo.jpg','https://r2.fivemanage.com/t/photo.jpg?signature=expiring','https://user:pass@r2.fivemanage.com/t/photo.jpg','https://r2.fivemanage.com/t/photo.jpg#secret']) {
    assert.throws(()=>publicUrl({status:'ok',data:{id:'photo',url}}));
  }
  await assert.rejects(uploadJpeg(image,id,'test-only-key',{request:transport(200,'{"status":"ok"}')}),/result is invalid/);
});
test('canonical original URL is used when account has a custom CDN',()=>{
  const photo=publicUrl({status:'ok',data:{id:'media_123',url:'https://custom.example/photo.webp',originalUrl:payload.data.url}});
  assert.equal(photo.url,payload.data.url);
});
test('redirect/auth/quota/server failures never expose provider bodies or credentials',async()=>{
  for(const status of [302,401,403,429,500]) {
    await assert.rejects(uploadJpeg(image,id,'test-only-key',{request:transport(status,'private-error-body')}),error=>{
      assert.match(error.message,/upload rejected/); assert.ok(!error.message.includes('private-error-body')); assert.ok(!error.message.includes('test-only-key')); return true;
    });
  }
});
test('reject absent key, malformed JPEG and oversized response',async()=>{
  await assert.rejects(uploadJpeg(image,id,''));
  await assert.rejects(uploadJpeg(Buffer.from('not-a-photo'),id,'test-only-key'));
  await assert.rejects(uploadJpeg(image,id,'test-only-key',{request:transport(200,'x'.repeat(65537))}),/exceeds limit/);
});
test('remote connection failures are sanitized',async()=>{
  const request=()=>{
    const req=new EventEmitter();req.setTimeout=()=>{};
    req.end=()=>queueMicrotask(()=>req.emit('error',new Error('private connection details')));
    return req;
  };
  await assert.rejects(uploadJpeg(image,id,'test-only-key',{request}),/FiveManage upload connection failed/);
});
test('FiveManage identity and permanent URL persist across store restart',async()=>{
  const directory=await fs.mkdtemp(path.join(os.tmpdir(),'photo-hosting-test-'));
  try {
    const store=new PhotoStore(directory,null);
    const allocation=await store.allocate();await fs.writeFile(allocation.fileName,image);
    const display=await store.finalize(allocation.id,{owner:'private-citizen',photographer:'Test Player'},publicUrl(payload));
    assert.equal(display.url,payload.data.url);assert.equal(display.public,true);assert.equal(display.owner,undefined);
    const restored=new PhotoStore(directory,null);
    assert.equal(restored.publicRecord(await restored.read(allocation.id)).url,payload.data.url);
    assert.equal((await restored.read(allocation.id)).hosting.fileId,'media_123');
  } finally {await fs.rm(directory,{recursive:true,force:true});}
});

test('provider file IDs remain opaque strings and never become local paths',()=>{
  const photo=publicUrl({status:'ok',data:{id:'d-photomode/file.jpg',url:payload.data.url}});
  assert.equal(photo.fileId,'d-photomode/file.jpg');
  assert.equal(photo.url,payload.data.url);
});
