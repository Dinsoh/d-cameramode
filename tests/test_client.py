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
        function TriggerEvent() error('QB notification path must not be used') end
        function BeginTextCommandThefeedPost() end
        function AddTextComponentSubstringPlayerName(text) notification=text end
        function EndTextCommandThefeedPostTicker() end
        function PlayerPedId() return 12 end
        function IsEntityDead() return dead end
        function IsPedInAnyVehicle() return inside end
        function IsGameplayCamRendering() return true end
        function GetTimecycleModifierIndex() return -1 end
        function GetExtraTimecycleModifierIndex() return -1 end
        local v={__sub=function() return setmetatable({},{__len=function() return displacement end}) end}
        function GetEntityCoords() return setmetatable({},v) end
        GetGameplayCamCoord=GetEntityCoords
        function GetGameplayCamFov() return gameplayFov or 70.0 end
        function GetGameplayCamRot() return {x=2,y=0,z=30} end
        function IsRadarHidden() return false end
        function GetGameTimer() return clock end
        function CreateCam() return 42 end
        function DoesCamExist() return true end
        function SetCamCoord(_,x,y,z) camera={x=x,y=y,z=z} end
        local vm={}
        function vector3(x,y,z) return setmetatable({x=x,y=y,z=z},vm) end
        vm.__add=function(a,b) return vector3(a.x+b.x,a.y+b.y,a.z+b.z) end
        vm.__sub=function(a,b) return vector3(a.x-b.x,a.y-b.y,a.z-b.z) end
        vm.__mul=function(a,n) return vector3(a.x*n,a.y*n,a.z*n) end
        vm.__len=function(a) return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z) end
        function StartExpensiveSynchronousShapeTestLosProbe(x,y,z,ex,ey,ez)
            probeEnd=vector3(ex,ey,ez); return 1
        end
        function GetShapeTestResult()
            if failedProbe then return 0,0,probeEnd end
            if tooClose then return 2,1,vector3(0,0.1,0.7) end
            if blocked then return 2,1,vector3(0,1,0.7) end
            return 2,0,probeEnd
        end
        function enterOrbit()
            commands.photomode()
            events['d-photomode:grant'](1,180,{origin={x=0,y=0,z=0},heading=0,
                distance=Config.Orbit.distance,height=Config.Orbit.height,
                targetHeight=0.7,maxDistance=5})
        end
        function SetCamRot() end
        function SetCamFov(_,n) fov=n end
        function SetCamUseShallowDofMode() end
        function SetCamNearDof(_,n) nearFocus=n end
        function SetCamFarDof(_,n) farFocus=n end
        function SetCamDofStrength(_,n) blur=n end
        function SetUseHiDof() end
        function SetCamActive() end
        function RenderScriptCams(on) rendering=on end
        function SetNuiFocus(on) focused=on end
        function SetNuiFocusKeepInput() end
        function SendNUIMessage(msg) message=msg end
        function DestroyCam() destroyed=true end
        function DisplayRadar(on) radar=on end
        function ClearExtraTimecycleModifier() cleared=true end
        function SetExtraTimecycleModifier() graded=true; gradeChanges=(gradeChanges or 0)+1 end
        function SetExtraTimecycleModifierStrength(n) gradeStrength=n end
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
        self.lua.execute("enter(); callbacks.update({fov=1000,filter=2},cb); assert(response.ok and fov==90 and graded); commands.photomode_exit(); assert(cleared)")
    def test_resource_stop_cleanup(self):
        self.lua.execute("enter(); handlers.onResourceStop('d-photomode'); assert(destroyed and not focused)")
    def test_unsolicited_grant_does_not_enter(self):
        self.lua.execute("events['d-photomode:grant'](1,180); assert(not rendering and calls[1][1]=='d-photomode:finish')")
    def test_orbit_presets_and_clamps(self):
        self.lua.execute("enterOrbit(); assert(math.abs(camera.y-2)<0.001); callbacks.update({angle=180,distance=999,height=999},cb); assert(response.ok and math.abs(camera.y+3)<0.001 and math.abs(camera.z-2.2)<0.001)")
    def test_collision_insets_camera(self):
        self.lua.execute("blocked=true; enterOrbit(); assert(rendering and math.abs(camera.y-0.8)<0.001)")
    def test_collision_rechecked_when_active(self):
        self.lua.execute("enterOrbit(); blocked=true; tick(); assert(math.abs(camera.y-0.8)<0.001)")
    def test_anchored_ignores_orbit_input(self):
        self.lua.execute("enter(); callbacks.update({angle=180,distance=3},cb); assert(response.ok and message.orbit==false)")
    def test_failed_probe_and_no_room_cleanup(self):
        for condition in ['failedProbe=true', 'tooClose=true']:
            with self.subTest(condition=condition):
                self.setUp(); self.lua.execute(condition+'; enterOrbit(); assert(destroyed and not focused and not rendering)')
    def test_bad_numbers_keep_valid_orbit(self):
        self.lua.execute("enterOrbit(); callbacks.update({angle='nan',distance='bad',height=math.huge},cb); assert(response.ok and math.abs(camera.y-2)<0.001 and math.abs(camera.z-0.9)<0.001)")
    def test_denial_does_not_require_qb_notify_or_lib(self):
        self.lua.execute("lib=nil; events['d-photomode:denied']('ACE denied'); assert(notification=='ACE denied' and not rendering)")
    def test_exit_notification_does_not_interrupt_cleanup(self):
        self.lua.execute("lib=nil; enter(); events['d-photomode:stop']('Session ended'); assert(notification=='Session ended' and destroyed and not focused and not rendering)")
    def test_entry_preserves_gameplay_fov_and_sends_reset_value(self):
        self.lua.execute("gameplayFov=72.5; enter(); assert(fov==72.5 and message.fov.default==72.5)")
    def test_wide_entry_fov_does_not_snap_to_configured_max(self):
        self.lua.execute("gameplayFov=100; enter(); assert(fov==100 and message.fov.max==100); callbacks.update({focus=2},cb); assert(fov==100)")
    def test_focus_and_blur_do_not_change_zoom(self):
        self.lua.execute("Config.EnableDof=true; enter(); callbacks.update({dof=true,focus=2,dofStrength=99},cb); assert(response.ok and fov==70 and nearFocus==1 and farFocus==3 and blur==1)")
    def test_filter_strength_is_clamped_without_reloading_grade(self):
        self.lua.execute("enter(); callbacks.update({filter=2,strength=99},cb); assert(gradeStrength==1 and gradeChanges==1); callbacks.update({filter=2,strength=-3},cb); assert(gradeStrength==0 and gradeChanges==1); callbacks.update({filter=1},cb); assert(cleared)")
if __name__=='__main__': unittest.main()
