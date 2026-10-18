"""Development-only contract tests; requires lupa. No FiveM/FINI claims."""
from pathlib import Path
import unittest
from lupa import LuaRuntime
ROOT = Path(__file__).resolve().parents[1] / 'd-photomode'

class Sessions(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute("""
        events, handlers, emitted = {}, {}, {}
        source, now, online, ace, alive, vehicle, distance, job = 7, 100, true, true, true, 0, 0, 'police'
        os.time = function() return now end
        local vec = { __sub = function() return setmetatable({}, {__len=function() return distance end}) end }
        exports = { ['qb-core'] = { GetCoreObject = function()
            return { Functions = { GetPlayer = function()
                if online then return {PlayerData={job={name=job},metadata={}}} end
            end } }
        end } }
        function RegisterNetEvent(name, fn) events[name] = fn end
        function AddEventHandler(name, fn) handlers[name] = fn end
        function TriggerClientEvent(name, src, ...) table.insert(emitted, {name,src,...}) end
        function IsPlayerAceAllowed() return ace end
        function GetPlayerPed() return online and 12 or 0 end
        function DoesEntityExist() return online end
        function GetEntityHealth() return alive and 200 or 0 end
        function GetVehiclePedIsIn() return vehicle end
        function GetEntityCoords() return setmetatable({},vec) end
        function Wait() coroutine.yield() end
        function CreateThread(fn) worker = coroutine.create(fn); assert(coroutine.resume(worker)) end
        function tick() assert(coroutine.resume(worker)) end
        function start() events['d-photomode:start']() end
        """)
        self.lua.execute((ROOT/'config.lua').read_text())
        self.lua.execute((ROOT/'server.lua').read_text())
    def run_lua(self, code): self.lua.execute(code)
    def test_grant_duplicate_and_cooldown(self):
        self.run_lua("start(); assert(#emitted==1 and emitted[1][1]=='d-photomode:grant'); start(); assert(#emitted==1); now=106; start(); assert(#emitted==1)")
    def test_permission_and_player_state(self):
        for setting in ['ace=false', 'online=false', 'alive=false', 'vehicle=4', "Config.AllowedJobs={'ambulance'}"]:
            with self.subTest(setting=setting):
                self.setUp(); self.run_lua(setting+"; start(); assert(emitted[1][1]=='d-photomode:denied')")
    def test_expiry_permission_and_position(self):
        for setting in ['now=281', 'ace=false', 'alive=false', 'distance=2', 'vehicle=4', 'online=false']:
            with self.subTest(setting=setting):
                self.setUp(); self.run_lua("start(); "+setting+"; tick(); assert(emitted[2][1]=='d-photomode:stop')")
    def test_stale_finish_cannot_cancel_new_session(self):
        self.run_lua("start(); events['d-photomode:finish'](99); now=106; start(); assert(#emitted==1); events['d-photomode:finish'](1); now=112; start(); assert(#emitted==2 and emitted[2][3]==2)")
    def test_disconnect_releases_state(self):
        self.run_lua("start(); handlers.playerDropped(); start(); assert(#emitted==2)")
    def test_lua_syntax(self):
        for path in ROOT.glob('*.lua'):
            self.lua.execute('assert(load(...))', path.read_text())

if __name__ == '__main__': unittest.main()
