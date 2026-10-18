"""Mocked client lifecycle checks. Does not validate engine native behavior."""
from pathlib import Path
import unittest
from lupa import LuaRuntime
ROOT=Path(__file__).resolve().parents[1]/'d-photomode'
class Client(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime()
        self.lua.execute('''
        events, commands, callbacks, handlers, calls = {}, {}, {}, {}, {}
        clock, dead, inside, displacement = 0, false, false, 0
        function RegisterNetEvent(n,f) events[n]=f end
        function RegisterCommand(n,f) commands[n]=f end
        function RegisterNUICallback(n,f) callbacks[n]=f end
        function AddEventHandler(n,f) handlers[n]=f end
        function RegisterKeyMapping() end
        function SetTimeout() end
        function GetCurrentResourceName() return 'd-photomode' end
        function TriggerServerEvent(n,...) table.insert(calls,{n,...}) end
        function TriggerEvent() end
        function PlayerPedId() return 12 end
        function IsEntityDead() return dead end
        function IsPedInAnyVehicle() return inside end
        function IsGameplayCamRendering() return true end
        function GetTimecycleModifierIndex() return -1 end
        function GetExtraTimecycleModifierIndex() return -1 end
        local v={__sub=function() return setmetatable({},{__len=function() return displacement end}) end}
        function GetEntityCoords() return setmetatable({},v) end
        GetGameplayCamCoord=GetEntityCoords
        function GetGameplayCamRot() return {x=2,y=0,z=30} end
        function IsRadarHidden() return false end
        function GetGameTimer() return clock end
        function CreateCam() return 42 end
        function DoesCamExist() return true end
        function SetCamCoord() end
        function SetCamRot() end
        function SetCamFov(_,n) fov=n end
        function SetCamUseShallowDofMode() end
        function SetCamActive() end
        function RenderScriptCams(on) rendering=on end
        function SetNuiFocus(on) focused=on end
        function SetNuiFocusKeepInput() end
        function SendNUIMessage(msg) message=msg end
        function DestroyCam() destroyed=true end
        function DisplayRadar(on) radar=on end
        function ClearExtraTimecycleModifier() cleared=true end
        function SetExtraTimecycleModifier() graded=true end
        function SetExtraTimecycleModifierStrength() end
        function Wait() coroutine.yield() end
        function CreateThread(fn) worker=coroutine.create(fn); assert(coroutine.resume(worker)) end
        function IsPedRagdoll() return false end
        function DisableAllControlActions() end
        function EnableControlAction() end
        function HideHudAndRadarThisFrame() end
        function tick() assert(coroutine.resume(worker)) end
        function enter() commands.photomode(); events['d-photomode:grant'](1,180) end
        function cb(result) response=result end
        ''')
        self.lua.execute((ROOT/'config.lua').read_text())
        self.lua.execute((ROOT/'client.lua').read_text())
    def test_entry_and_idempotent_cleanup(self):
        self.lua.execute("enter(); assert(rendering and focused); commands.photomode_exit(); assert(not rendering and not focused and destroyed and radar); local n=#calls; commands.photomode_exit(); assert(#calls==n)")
    def test_interruptions_cleanup(self):
        for condition in ['dead=true','inside=true','displacement=2','clock=181000']:
            with self.subTest(condition=condition):
                self.setUp(); self.lua.execute('enter(); '+condition+'; tick(); assert(destroyed and not focused and not rendering)')
    def test_bounded_input_and_grade_cleanup(self):
        self.lua.execute("enter(); callbacks.update({fov=1000,filter=2},cb); assert(response.ok and fov==80 and graded); commands.photomode_exit(); assert(cleared)")
    def test_resource_stop_cleanup(self):
        self.lua.execute("enter(); handlers.onResourceStop('d-photomode'); assert(destroyed and not focused)")
    def test_unsolicited_grant_does_not_enter(self):
        self.lua.execute("events['d-photomode:grant'](1,180); assert(not rendering and calls[1][1]=='d-photomode:finish')")
if __name__=='__main__': unittest.main()
