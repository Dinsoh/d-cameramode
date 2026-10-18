'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs/promises');
const path=require('node:path');
const os=require('node:os');
const {EventEmitter}=require('node:events');
const {PhotoStore,ID}=require('../d-photomode/storage-core.js');
const provider=require('../d-photomode/fivemanage.js');
const image=Buffer.from([255,216,1,2,255,217]);
const metadata={owner:'test-private-owner',photographer:'Test Player',caption:'A moment'};
async function fixture(fn,{defer=false,failUpload=false,failWrite=false,badEncoding=false}={}) {
  const directory=await fs.mkdtemp(path.join(os.tmpdir(),'photo-bridge-test-'));
  const api={},shots=[],warnings=[];let http,uploads=0;
  const exported=(name,fn)=>{api[name]=fn;};
  exported.screencapture={serverCapture(player,options,callback,dataType){
    assert.equal(dataType,'base64'); assert.equal(options.encoding,'jpeg');
    assert.equal(options.maxWidth,1920); assert.equal(options.maxHeight,1080);
    shots.push({player,options,callback});
    const captureBytes = badEncoding ? Buffer.from([137,80,78,71,13,10,26,10]) : image;
    assert.equal(options.fileName,undefined);
    if(!defer) queueMicrotask(()=>{callback('data:image/jpeg;base64,'+captureBytes.toString('base64'));callback('data:image/jpeg;base64,'+captureBytes.toString('base64'));});
  }};
  const request=(url,options,cb)=>{
    uploads++;
    assert.equal(options.headers.Authorization,'test-only-key');
    const req=new EventEmitter();req.setTimeout=()=>{};req.destroy=error=>req.emit('error',error);
    req.end=()=>queueMicrotask(()=>{
      const response=new EventEmitter();response.statusCode=failUpload?401:200;response.destroy=()=>{};
      cb(response);response.emit('data',Buffer.from(JSON.stringify({status:'ok',data:{id:'server-media',url:'https://r2.fivemanage.com/team/server-media.jpg'}})));response.emit('end');
    });return req;
  };
  const context={exports:exported,GetCurrentResourceName:()=> 'd-photomode',GetResourcePath:()=> directory,
    GetConvar:(name,fallback)=>name==='d_photomode_fivemanage_key'?'test-only-key':fallback,
    GetConvarInt:(_,fallback)=>fallback,GetResourceState:()=> 'started',
    SetHttpHandler:fn=>{http=fn;},Buffer,AbortController,setTimeout,clearTimeout,console:{...console,warn:line=>warnings.push(line)},
    require:name=>name==='node:fs/promises' && failWrite ? {...fs,writeFile:async()=>{throw Object.assign(new Error('private-path-and-secret-must-not-leak'),{code:'EACCES'});}} : name.endsWith('/storage-core.js')?{PhotoStore,ID}:name.endsWith('/fivemanage.js')?{uploadJpeg:(image,id,key,opts)=>provider.uploadJpeg(image,id,key,{...opts,request})}:require(name)};
  context.global=context;
  vm.runInNewContext(await fs.readFile(path.join(__dirname,'../d-photomode/storage.js'),'utf8'),context);
  const capture=player=>new Promise(resolve=>api.capturePhotoToStorage(player,metadata,(error,photo)=>resolve({error,photo})));
  try {await fn({api,shots,capture,directory,warnings,get uploads(){return uploads;},http});}
  finally {for(let player=1;player<=8;player++) api.cancelPhotoCapture(player);await fs.rm(directory,{recursive:true,force:true});}
}
test('server bridge captures/uploads once and returns a record without credentials or owner',async()=>fixture(async state=>{
  const {error,photo}=await state.capture(1);assert.equal(error,null);assert.ok(photo.id);assert.equal(state.uploads,1);assert.equal(photo.url,'https://r2.fivemanage.com/team/server-media.jpg');
  assert.equal(photo.owner,undefined);assert.ok(!JSON.stringify(photo).includes('test-only-key'));
  const record=await new Promise(resolve=>state.api.readPhotoRecord(photo.id,(_,record)=>resolve(record)));
  assert.equal(record.owner,metadata.owner);
  let status;state.http({method:'GET',path:`/photos/${photo.id}.jpg`},{writeHead:code=>{status=code;},send:()=>{}});assert.equal(status,404);
}));
test('failed provider upload returns no ready photo record',async()=>fixture(async state=>{
  const result=await state.capture(1);assert.ok(result.error);assert.equal(result.photo,null);
  const files=await fs.readdir(path.join(state.directory,'data/photos'));
  assert.equal(files.filter(name=>name.endsWith('.json')).length,0);
},{failUpload:true}));
test('concurrency is bounded and cancellation prevents late completion',async()=>fixture(async state=>{
  const pending=[1,2,3,4].map(state.capture);
  const rejected=await state.capture(5);assert.ok(rejected.error);
  const deadline=Date.now()+2000; while(state.shots.length<4 && Date.now()<deadline) await new Promise(resolve=>setTimeout(resolve,5));
  assert.equal(state.shots.length,4);
  state.api.cancelPhotoCapture(1);
  const first=await pending[0];assert.ok(first.error);assert.equal(first.photo,null);
  for(const player of [2,3,4]) state.api.cancelPhotoCapture(player);
  await Promise.all(pending);
  // Late screenshot completions cannot upload or publish inventory-ready photos.
  for(const shot of state.shots) shot.callback(false);
  assert.equal(state.uploads,0);
},{defer:true}));

test('filesystem failure identifies stage and safe code without exposing paths or secrets',async()=>fixture(async state=>{
  const result=await state.capture(1); assert.ok(result.error.includes('storage failed')); assert.equal(result.photo,null);
  assert.equal(state.warnings.length,1); assert.match(state.warnings[0],/write-image: EACCES/);
  assert.ok(!state.warnings[0].includes('private-path-and-secret')); assert.equal(state.uploads,0);
},{failWrite:true}));

test('JPEG-labelled PNG from an upstream encoder is rejected before upload or publication',async()=>fixture(async state=>{
  const result=await state.capture(1); assert.equal(result.photo,null); assert.equal(state.uploads,0);
  assert.match(state.warnings[0],/validate-image: Capture is not a JPEG/);
  assert.equal((await fs.readdir(path.join(state.directory,'data/photos'))).filter(name=>name.endsWith('.json')).length,0);
},{badEncoding:true}));
