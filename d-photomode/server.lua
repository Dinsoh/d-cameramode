local QBCore = exports['qb-core']:GetCoreObject()
local sessions, attempts = {}, {}
local serial = 0

local function allowed(src)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return false end
    if Config.RequireAce and not IsPlayerAceAllowed(src, Config.Ace) then return false end
    local jobs = Config.AllowedJobs
    if #jobs == 0 then return true end
    for _, job in ipairs(jobs) do
        if player.PlayerData.job and player.PlayerData.job.name == job then return true end
    end
    return false
end

local function validPed(src)
    local ped = GetPlayerPed(src)
    if ped == 0 or not DoesEntityExist(ped) or GetEntityHealth(ped) <= 0 then return end
    local player = QBCore.Functions.GetPlayer(src)
    local meta = player and player.PlayerData.metadata or {}
    if meta.isdead or meta.inlaststand or GetVehiclePedIsIn(ped, false) ~= 0 then return end
    return ped
end

local function stop(src, reason)
    if not sessions[src] then return end
    sessions[src] = nil
    TriggerClientEvent('d-photomode:stop', src, reason)
end

RegisterNetEvent('d-photomode:start', function()
    local src, now = source, os.time()
    if attempts[src] and now - attempts[src] < Config.StartCooldownSeconds then return end
    attempts[src] = now
    if sessions[src] then return end
    local ped = validPed(src)
    if not allowed(src) or not ped then
        TriggerClientEvent('d-photomode:denied', src)
        return
    end
    serial = serial + 1
    local s = { id = serial, origin = GetEntityCoords(ped), expires = now + Config.SessionSeconds, ped = ped }
    sessions[src] = s
    TriggerClientEvent('d-photomode:grant', src, s.id, Config.SessionSeconds)
end)

RegisterNetEvent('d-photomode:finish', function(id)
    local src = source
    if sessions[src] and sessions[src].id == id then sessions[src] = nil end
end)

AddEventHandler('playerDropped', function()
    sessions[source], attempts[source] = nil, nil
end)

-- Only active sessions are examined; no player/vehicle sweeps or camera broadcasts.
CreateThread(function()
    while true do
        Wait(1000)
        for src, s in pairs(sessions) do
            local ped = validPed(src)
            if os.time() >= s.expires or not allowed(src) or not ped or ped ~= s.ped then
                stop(src, 'Session ended')
            elseif #(GetEntityCoords(ped) - s.origin) > Config.MaxPedDisplacement then
                stop(src, 'Position changed')
            end
        end
    end
end)
