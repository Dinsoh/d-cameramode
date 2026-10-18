"""Optional: execute readable vendor exports from the privately supplied QS archive.
Set QS_REFERENCE_DIR to the extracted inventory root. No vendor source is bundled.
"""
import os
from pathlib import Path
import unittest
from lupa.lua54 import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]/'d-photomode'
REFERENCE=Path(os.environ.get('QS_REFERENCE_DIR','/nonexistent-qs-reference'))
@unittest.skipUnless((REFERENCE/'server/custom/misc/AddItem.lua').exists(),'QS_REFERENCE_DIR not supplied')
class QsReference(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime()
        self.lua.execute('''
        function clone(x) if type(x)~='table' then return x end;local t={};for k,v in pairs(x) do t[k]=clone(v) end;return t end
        json={encode=clone,decode=clone}
        table.matches=function(a,b) for k,v in pairs(a) do if b[k]~=v then return false end end;for k,v in pairs(b) do if a[k]~=v then return false end end;return true end
        Config={InventoryResource='qs-inventory',Items={camera='polaroid_camera',film='polaroid_film',photo='polaroid_photo'},RequireFilm=true,InventoryWeight={slots=4,weight=10000},InventoryPrefix='qs-inventory'}
        ItemList={polaroid_camera={name='polaroid_camera',type='item',weight=350,unique=false,stack=true},polaroid_film={name='polaroid_film',type='item',weight=15,unique=false,stack=true},polaroid_photo={name='polaroid_photo',type='item',weight=5,unique=true,stack=false}}
        Inventories={[7]={[1]={name='polaroid_camera',amount=1,slot=1,info={},weight=350},[2]={name='polaroid_film',amount=3,slot=2,info={quality=100},weight=15}}}
        player={PlayerData={items=Inventories[7]}}
        local registered={}
        local qs=setmetatable({}, {__index=function(_,name) return function(_,...) return registered[name](...) end end})
        exports=setmetatable({['qb-core']={GetCoreObject=function() return {Shared={Items=ItemList},Functions={GetPlayer=function() return player end}} end},['qs-inventory']=qs},{__call=function(_,name,fn) registered[name]=fn end})
        function GetResourceState(name) return name=='qs-inventory' and 'started' or 'missing' end
        function GetGameTimer() return 100 end
        function Error(...) error('Unexpected vendor error') end
        function Debug() end
        function TriggerEvent() end
        function TriggerClientEvent() end
        function NotStoredItems() return false end
        function Lang(s) return s end
        function ContainsItem() return false end
        itemsToCheck={}
        function UpdateFrameworkInventory(src,items) player.PlayerData.items=items end
        function UpdateInventoryState() end
        function GetFirstSlotByItem(items,name) for slot,item in pairs(items) do if item.name==name then return slot end end end
        function GetTotalUsedSlots(src)
            local count,weight=0,0;for _,item in pairs(Inventories[src]) do count=count+1;weight=weight+(ItemList[item.name].weight*item.amount) end;return count,weight
        end
        function ItemInfo(item) item.weight=ItemList[item.name].weight;item.unique=ItemList[item.name].unique;item.count=item.amount;return item end
        ''')
        for name in ['shared/inventory.lua','server/custom/misc/AddItem.lua','server/custom/misc/RemoveItem.lua']:
            self.lua.execute((REFERENCE/name).read_text())
        self.lua.execute((ROOT/'inventory.lua').read_text())
    def test_real_qs_exports_preserve_unique_metadata_and_film_refund(self):
        self.lua.execute("""
        local film=PhotoInventory.film(7);assert(PhotoInventory.removeFilm(7,film));assert(PhotoInventory.refundFilm(7,film));assert(PhotoInventory.count(7,'polaroid_film')==3)
        assert(PhotoInventory.addPhoto(7,{id='12345678-1234-4234-8234-123456789abc',url='https://r2.fivemanage.com/team/a.jpg',takenAt='now',photographer='Test'}))
        assert(PhotoInventory.addPhoto(7,{id='12345678-1234-4234-8234-123456789abd',url='https://r2.fivemanage.com/team/b.jpg',takenAt='now',photographer='Other'}))
        assert(Inventories[7][3].info.photoId~=Inventories[7][4].info.photoId)
        assert(Inventories[7][3].amount==1 and Inventories[7][4].amount==1)
        assert(not CanStackItems(Inventories[7][3],Inventories[7][4]))
        """)
    def test_real_qs_capacity_failure_and_refund(self):
        self.lua.execute("""
        Config.InventoryWeight.slots=2
        local film=PhotoInventory.film(7);assert(PhotoInventory.removeFilm(7,film))
        assert(not PhotoInventory.addPhoto(7,{id='12345678-1234-4234-8234-123456789abc',url='https://r2.fivemanage.com/team/a.jpg',takenAt='now',photographer='Test'}))
        assert(PhotoInventory.refundFilm(7,film) and PhotoInventory.count(7,'polaroid_film')==3)
        """)
if __name__=='__main__': unittest.main()
