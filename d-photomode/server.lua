local QBCore = exports['qb-core']:GetCoreObject()
local sessions, attempts = {}, {}
local serial = 0

local function allowed(src)
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return false, 'Your character is not ready yet.' end
    if Config.RequireAce and not IsPlayerAceAllowed(src, Config.Ace) then
        return false, 'Photo mode requires ACE permission: ' .. Config.Ace
    end
    local jobs = Config.AllowedJobs
    if #jobs == 0 then return true end
    for _, job in ipairs(jobs) do
        if player.PlayerData.job and player.PlayerData.job.name == job then return true end
    end
    return false, 'Your current job cannot use photo mode.'
end

local function validPed(src)
    local ped = GetPlayerPed(src)
    if ped == 0 or not DoesEntityExist(ped) then return nil, 'Your player is not ready yet.' end
    if GetEntityHealth(ped) <= 0 then return nil, 'Photo mode is unavailable while dead.' end
    local player = QBCore.Functions.GetPlayer(src)
    local meta = player and player.PlayerData.metadata or {}
    if meta.isdead or meta.inlaststand then return nil, 'Photo mode is unavailable while downed.' end
    if GetVehiclePedIsIn(ped, false) ~= 0 then return nil, 'Leave your vehicle before using photo mode.' end
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
    local permitted, permissionReason = allowed(src)
    local ped, stateReason = validPed(src)
    if not permitted or not ped then
        TriggerClientEvent('d-photomode:denied', src, permissionReason or stateReason)
        return
    end
    serial = serial + 1
    local s = { id = serial, origin = GetEntityCoords(ped), expires = now + Config.SessionSeconds, ped = ped }
    sessions[src] = s
    local orbit
    if Config.Orbit.enabled then
        orbit = { origin = { x = s.origin.x, y = s.origin.y, z = s.origin.z },
            heading = GetEntityHeading(ped), distance = Config.Orbit.distance,
            height = Config.Orbit.height, targetHeight = Config.Orbit.targetHeight,
            maxDistance = Config.MaxCameraDistance }
    end
    TriggerClientEvent('d-photomode:grant', src, s.id, Config.SessionSeconds, orbit)
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
