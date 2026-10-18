"""Server workflow with QS-signature doubles. Actual QS persistence still needs live QA."""
from pathlib import Path
import unittest
from lupa.lua54 import LuaRuntime
ROOT = Path(__file__).resolve().parents[1] / 'd-photomode'

class Polaroid(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute(r'''
        events, handlers, commands, usable, emitted, timers = {}, {}, {}, {}, {}, {}
        records, journals = {}, {}
        source, now, clock, uploadCount = 7, 100, 10000, 0
        alive, ace, vehicle, distance = true, true, 0, 0
        players = {
            [7]={PlayerData={source=7,citizenid='owner-seven',charinfo={firstname='Test',lastname='Player'},metadata={},job={name='police'},items={
                [1]={name='polaroid_camera',amount=1,slot=1,info={}},
                [2]={name='polaroid_film',amount=3,slot=2,info={quality=100}}
            }}},
            [8]={PlayerData={source=8,citizenid='owner-eight',charinfo={firstname='Other',lastname='Player'},metadata={},job={name='civilian'},items={}}}
        }
        function clone(value)
            if type(value)~='table' then return value end
            local result={}; for k,v in pairs(value) do result[k]=clone(v) end; return result
        end
        json={encode=clone, decode=clone}
        core={Shared={Items={polaroid_camera={unique=false},polaroid_film={unique=false},polaroid_photo={unique=true,stack=false}}},Functions={}}
        core.Functions.GetPlayer=function(src) return players[src] end
        core.Functions.CreateUseableItem=function(name,fn) usable[name]=fn end
        core.Functions.GetPlayerByCitizenId=function(id) for _,p in pairs(players) do if p.PlayerData.citizenid==id then return p end end end
        local function qsAdd(_,src,name,amount,slot,info)
            if name=='polaroid_photo' and (full or failAdd) then return false end
            if name=='polaroid_film' and failRefund then return false end
            local items=players[src].PlayerData.items
            if name=='polaroid_film' and items[2] and items[2].name==name then items[2].amount=items[2].amount+amount; return true end
            for i=1,41 do if not items[i] then items[i]={name=name,amount=amount,slot=i,info=clone(info or {})}; if loseCameraOnAdd and name=='polaroid_photo' then items[1]=nil end; return true end end
            return false
        end
        local function qsRemove(_,src,name,amount,slot)
            if failRemove then return false end
            local items=players[src].PlayerData.items;local item=items[slot]
            if not item or item.name~=name or item.amount<amount then return false end
            item.amount=item.amount-amount;if item.amount==0 then items[slot]=nil end;return true
        end
        exports={['qb-core']={GetCoreObject=function() return core end},['qs-inventory']={AddItem=qsAdd,RemoveItem=qsRemove},['d-photomode']={}}
        local backend=exports['d-photomode']
        backend.capturePhotoToStorage=function(_,src,metadata,cb,progress)
            uploadCount=uploadCount+1; pendingUpload={src=src,metadata=clone(metadata),cb=cb,progress=progress}
        end
        backend.cancelPhotoCapture=function() cancelled=(cancelled or 0)+1 end
        backend.prepareDelivery=function(_,id,owner,film,cb)
            if prepareFails or journals[id] then cb('Cannot prepare');return end
            journals[id]={phase='prepared',owner=owner,film=clone(film)};cb(nil,journals[id])
        end
        backend.settleDelivery=function(_,id,owner,phase,cb)
            local journal=journals[id]
            if not journal or journal.owner~=owner then cb('Invalid journal');return end
            journal.phase=phase;cb(nil,journal)
        end
        backend.readPhotoDisplay=function(_,id,cb) if records[id] then cb(nil,clone(records[id])) else cb('Missing') end end
        backend.readPhotoDelivery=function(_,id,cb) if journals[id] then cb(nil,clone(journals[id])) else cb('Missing') end end
        function finishUpload(ok)
            if not ok then pendingUpload.cb('Upload failed');return end
            local id=string.format('12345678-1234-4234-8234-%012d',uploadCount)
            lastPhoto=id
            records[id]={id=id,url='https://r2.fivemanage.com/team/'..id..'.jpg',public=true,photographer=pendingUpload.metadata.photographer,caption=pendingUpload.metadata.caption,takenAt='2026-10-18T00:00:00Z'}
            pendingUpload.progress('captured'); pendingUpload.cb(nil,clone(records[id]))
        end
        function RegisterNetEvent(n,fn) events[n]=fn end
        function AddEventHandler(n,fn) handlers[n]=fn end
        function RegisterCommand(n,fn) commands[n]=fn end
        function TriggerClientEvent(n,src,...) table.insert(emitted,{n,src,...}) end
        function GetCurrentResourceName() return 'd-photomode' end
        function GetInvokingResource() return 'qs-inventory' end
        function GetResourceState() return 'started' end
        function GetGameTimer() return clock end
        function GetPlayerPed(src) return players[src] and src+10 or 0 end
        function DoesEntityExist() return true end
        function GetEntityHealth() return alive and 200 or 0 end
        function IsPlayerAceAllowed() return ace end
        function GetVehiclePedIsIn() return vehicle end
        function GetEntityHeading() return 0 end
        function NetworkGetEntityFromNetworkId() return propReady and 99 or 0 end
        function NetworkGetNetworkIdFromEntity() return 500 end
        function NetworkGetEntityOwner() return propOwner or 7 end
        function GetEntityType() return 3 end
        function GetEntityModel() return 1 end
        function GetHashKey() return 1 end
        function DeleteEntity() propDeleted=true end
        local vm={__sub=function() return setmetatable({},{__len=function() return distance end}) end}
        function GetEntityCoords() return setmetatable({x=0,y=0,z=0},vm) end
        function SetTimeout(ms,fn) table.insert(timers,fn) end
        function flushTimers() local queue=timers;timers={};for _,fn in ipairs(queue) do fn() end end
        function Wait() coroutine.yield() end
        function CreateThread(fn) worker=coroutine.create(fn);assert(coroutine.resume(worker)) end
        function tick() assert(coroutine.resume(worker)) end
        os.time=function() return now end
        function start() events['d-photomode:start']() end
        function shoot() start();events['d-photomode:capture'](1,'A moment');events['d-photomode:captureReady'](1,1) end
        function photograph(src) return PhotoInventory.find(src or 7,'polaroid_photo') end
        function lastEvent(name) for i=#emitted,1,-1 do if emitted[i][1]==name then return emitted[i] end end end
        ''')
        for name in ['config.lua', 'inventory.lua', 'server.lua']:
            self.lua.execute((ROOT/name).read_text())
            if name == 'config.lua': self.lua.execute('Config.RequireAce=true')
    def run_lua(self, code): self.lua.execute(code)
    def test_item_dispatch_and_camera_ownership(self):
        self.run_lua("usable.polaroid_camera(7,players[7].PlayerData.items[1]);assert(lastEvent('d-photomode:useCamera'));players[7].PlayerData.items[1]=nil;start();assert(lastEvent('d-photomode:denied')[3]:find('need your Polaroid'))")
    def test_success_prints_one_unique_photo_and_charges_one_film(self):
        self.run_lua("shoot();assert(uploadCount==1 and PhotoInventory.count(7,'polaroid_film')==3);finishUpload(true);flushTimers();local item=photograph();assert(item and item.amount==1 and item.info.photoId==lastPhoto and item.info.url==records[lastPhoto].url);assert(PhotoInventory.count(7,'polaroid_film')==2 and journals[lastPhoto].phase=='delivered');assert(lastEvent('d-photomode:captureResult')[5]==true)")
    def test_ready_and_upload_replays_cannot_duplicate_prints(self):
        self.run_lua("shoot();events['d-photomode:captureReady'](1,1);events['d-photomode:capture'](1,'repeat');assert(uploadCount==1);finishUpload(true);finishUpload(true);flushTimers();assert(PhotoInventory.count(7,'polaroid_photo')==1 and PhotoInventory.count(7,'polaroid_film')==2)")
    def test_upload_failure_and_cancel_do_not_consume_film(self):
        for condition in ["finishUpload(false)", "events['d-photomode:finish'](1);finishUpload(true);flushTimers()"]:
            with self.subTest(condition=condition):
                self.setUp();self.run_lua("shoot();"+condition+";assert(not photograph() and PhotoInventory.count(7,'polaroid_film')==3)")
    def test_full_inventory_refunds_exact_film_and_no_photo(self):
        self.run_lua("shoot();full=true;finishUpload(true);flushTimers();assert(not photograph() and PhotoInventory.count(7,'polaroid_film')==3);assert(journals[lastPhoto].phase=='refunded')")
    def test_failed_refund_is_durable_and_console_recovery_is_single_use(self):
        self.run_lua("shoot();full=true;failRefund=true;finishUpload(true);flushTimers();assert(journals[lastPhoto].phase=='refund_pending' and PhotoInventory.count(7,'polaroid_film')==2);failRefund=false;commands.photomode_refund(0,{lastPhoto});assert(journals[lastPhoto].phase=='refunded' and PhotoInventory.count(7,'polaroid_film')==3);commands.photomode_refund(0,{lastPhoto});assert(PhotoInventory.count(7,'polaroid_film')==3)")
    def test_changed_film_camera_identity_or_permission_before_print(self):
        for condition in ["players[7].PlayerData.items[2]=nil", "players[7].PlayerData.items[1]=nil", "players[7].PlayerData.citizenid='different-character'", 'ace=false', 'alive=false', 'distance=5']:
            with self.subTest(condition=condition):
                self.setUp(); self.run_lua("shoot();finishUpload(true);"+condition+";flushTimers();assert(not photograph())")
    def test_prepare_failure_is_not_charged(self):
        self.run_lua("shoot();prepareFails=true;finishUpload(true);flushTimers();assert(not photograph() and PhotoInventory.count(7,'polaroid_film')==3)")
    def test_film_requirement_is_optional(self):
        self.run_lua("Config.RequireFilm=false;players[7].PlayerData.items[2]=nil;shoot();finishUpload(true);flushTimers();assert(photograph() and journals[lastPhoto].phase=='delivered')")
    def test_view_uses_server_record_and_rechecks_ownership(self):
        self.run_lua("shoot();finishUpload(true);flushTimers();local item=photograph();item.info.url='https://evil.example/forged.jpg';usable.polaroid_photo(7,item);assert(lastEvent('d-photomode:viewPhoto')[3].url==records[lastPhoto].url)")
    def test_transfer_preserves_identity_and_new_owner_can_open(self):
        self.run_lua("shoot();finishUpload(true);flushTimers();local item,slot=photograph();players[8].PlayerData.items[4]=clone(item);players[8].PlayerData.items[4].slot=4;players[7].PlayerData.items[slot]=nil;usable.polaroid_photo(8,players[8].PlayerData.items[4]);local view=lastEvent('d-photomode:viewPhoto');assert(view[2]==8 and view[3].id==lastPhoto and not PhotoInventory.find(7,'polaroid_photo',lastPhoto))")
    def test_restarting_orchestrator_preserves_existing_inventory_photo(self):
        self.run_lua("shoot();finishUpload(true);flushTimers()")
        self.lua.execute((ROOT/'server.lua').read_text())
        self.run_lua("clock=12000;usable.polaroid_photo(7,photograph());assert(lastEvent('d-photomode:viewPhoto')[3].id==lastPhoto and PhotoInventory.count(7,'polaroid_photo')==1)")
    def test_camera_loss_event_stops_session(self):
        self.run_lua("start();players[7].PlayerData.items[1]=nil;events['d-photomode:inventoryChanged']();flushTimers();assert(lastEvent('d-photomode:stop'))")
    def test_overlay_ready_deadline_rejects_late_capture(self):
        self.run_lua("start();events['d-photomode:capture'](1,'caption');now=106;tick();events['d-photomode:captureReady'](1,1);assert(uploadCount==0 and PhotoInventory.count(7,'polaroid_film')==3)")
    def test_qs_event_and_qb_callback_are_deduplicated(self):
        self.run_lua("handlers['inventory:usedItem']('polaroid_camera',7,players[7].PlayerData.items[1]);usable.polaroid_camera(7,players[7].PlayerData.items[1]);local count=0;for _,event in ipairs(emitted) do if event[1]=='d-photomode:useCamera' then count=count+1 end end;assert(count==1)")
    def test_caption_is_bounded_plain_text_and_utf8_safe(self):
        self.run_lua("start();events['d-photomode:capture'](1,string.rep('é',100)..'<script>');events['d-photomode:captureReady'](1,1);assert(utf8.len(pendingUpload.metadata.caption)==80)")
    def test_inventory_interruption_during_add_rolls_back_the_new_photo(self):
        self.run_lua("shoot();loseCameraOnAdd=true;finishUpload(true);flushTimers();assert(not photograph() and PhotoInventory.count(7,'polaroid_film')==3 and journals[lastPhoto].phase=='refunded')")
    def test_delayed_prop_replication_is_validated_and_cleaned(self):
        self.run_lua("start();events['d-photomode:prop'](1,500);propReady=true;flushTimers();events['d-photomode:finish'](1);assert(propDeleted)")
    def test_other_players_prop_is_not_deleted(self):
        self.run_lua("start();propReady=true;propOwner=8;events['d-photomode:prop'](1,500);assert(not propDeleted and lastEvent('d-photomode:stop'))")
if __name__=='__main__': unittest.main()
