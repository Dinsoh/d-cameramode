local QBCore = exports['qb-core']:GetCoreObject()
local sessions, attempts = {}, {}
local serial, captureSerial = 0, 0
local captureAttempts, viewReads, viewedPhotos, inventoryChecks, props, useTimes = {}, {}, {}, {}, {}, {}
local cancelCapture
local resource = GetCurrentResourceName()

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

local function stop(src, reason, notifyClient)
    if not sessions[src] then return end
    local s = sessions[src]
    sessions[src] = nil
    if s.prop and DoesEntityExist(s.prop) and NetworkGetNetworkIdFromEntity(s.prop) == s.propNet then DeleteEntity(s.prop) end
    if s.prop then props[s.prop] = nil end
    pcall(function() exports[resource]:cancelPhotoCapture(src) end)
    if notifyClient ~= false then TriggerClientEvent('d-photomode:stop', src, reason) end
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
    if not PhotoInventory.definitionsValid() then
        TriggerClientEvent('d-photomode:denied', src, 'Camera items are not configured correctly. Contact staff.') return
    end
    if not PhotoInventory.hasCamera(src) then
        TriggerClientEvent('d-photomode:denied', src, 'You need your Polaroid camera to enter photo mode.') return
    end
    serial = serial + 1
    local s = { id = serial, origin = GetEntityCoords(ped), expires = now + Config.SessionSeconds, ped = ped, owner = QBCore.Functions.GetPlayer(src).PlayerData.citizenid }
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
    if sessions[src] and sessions[src].id == id then stop(src, nil, false) end
end)

AddEventHandler('playerDropped', function()
    local src = source
    stop(src, nil, false)
    attempts[src], captureAttempts[src], viewReads[src], viewedPhotos[src], inventoryChecks[src], useTimes[src] = nil, nil, nil, nil, nil, nil
end)

-- Only active sessions are examined; no player/vehicle sweeps or camera broadcasts.
CreateThread(function()
    while true do
        Wait(1000)
        for src, s in pairs(sessions) do
            local ped = validPed(src)
            local player = QBCore.Functions.GetPlayer(src)
            if not player or player.PlayerData.citizenid ~= s.owner or os.time() >= s.expires or not allowed(src) or not ped or ped ~= s.ped then
                stop(src, 'Session ended')
            elseif #(GetEntityCoords(ped) - s.origin) > Config.MaxPedDisplacement then
                stop(src, 'Position changed')
            elseif s.capture and os.time() >= s.capture.deadline and cancelCapture then
                cancelCapture(src, s, s.capture, 'Capture timed out. No film was charged.')
            end
        end
    end
end)

local function captureValid(src, s, capture)
    local player = QBCore.Functions.GetPlayer(src)
    local ped = validPed(src)
    return sessions[src] == s and s.capture == capture and player and player.PlayerData.citizenid == s.owner
        and os.time() < s.expires and allowed(src) and ped == s.ped
        and #(GetEntityCoords(ped) - s.origin) <= Config.MaxPedDisplacement and PhotoInventory.hasCamera(src)
end
local function result(src, s, capture, ok, message)
    if sessions[src] ~= s or s.capture ~= capture then return end
    s.capture = nil
    TriggerClientEvent('d-photomode:captureResult', src, s.id, capture.id, ok, message)
end
cancelCapture = function(src, s, capture, message)
    result(src, s, capture, false, message)
    pcall(function() exports[resource]:cancelPhotoCapture(src) end)
end

RegisterNetEvent('d-photomode:prop', function(id, netId)
    local src, s = source, sessions[source]
    if not s or s.id ~= id or s.prop or s.pendingProp or type(netId) ~= 'number' or netId < 1 or netId > 65535 or netId % 1 ~= 0 then return end
    s.pendingProp = netId
    local function resolve(attempt)
        if sessions[src] ~= s then return end
        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity == 0 then
            if attempt < 10 then SetTimeout(200, function() resolve(attempt + 1) end)
            else stop(src, 'The camera prop could not be synchronized. Please try again.') end
            return
        end
        if not DoesEntityExist(entity) or props[entity] and props[entity] ~= src or GetEntityType(entity) ~= 3 or NetworkGetEntityOwner(entity) ~= src
            or GetEntityModel(entity) ~= GetHashKey(Config.Prop.model)
            or #(GetEntityCoords(entity) - GetEntityCoords(s.ped)) > 3.0 then
            stop(src, 'The camera prop could not be validated.') return
        end
        s.pendingProp = nil
        s.prop, s.propNet, props[entity] = entity, netId, src
    end
    resolve(1)
end)
AddEventHandler('entityRemoved', function(entity)
    local src = props[entity]
    if src and sessions[src] and sessions[src].prop == entity then sessions[src].prop = nil end
    props[entity] = nil
end)

local function cleanText(value, limit)
    if type(value) ~= 'string' then return '' end
    value = value:gsub('[%c]', '')
    local length = utf8.len(value)
    if not length then return '' end
    if length > limit then return value:sub(1, utf8.offset(value, limit + 1) - 1) end
    return value
end

RegisterNetEvent('d-photomode:capture', function(id, caption)
    local src, s, now = source, sessions[source], os.time()
    if not s or s.id ~= id or s.capture then return end
    if captureAttempts[src] and now - captureAttempts[src] < Config.CaptureCooldownSeconds then
        TriggerClientEvent('d-photomode:captureResult', src, id, 0, false, 'Wait a moment before taking another photograph.') return
    end
    captureAttempts[src] = now
    captureSerial = captureSerial + 1
    local c = {id = captureSerial, phase = 'waiting_ui', deadline = now + 5}
    s.capture = c
    if not captureValid(src, s, c) then result(src, s, c, false, 'Your camera session is no longer valid.') return end
    if Config.RequireFilm and not PhotoInventory.film(src) then result(src, s, c, false, 'You need film for this photograph.') return end
    caption = cleanText(caption, math.max(0, math.min(120, Config.CaptionLength)))
    local char = QBCore.Functions.GetPlayer(src).PlayerData.charinfo or {}
    c.metadata = {owner = s.owner, photographer = cleanText((char.firstname or '') .. ' ' .. (char.lastname or ''), 100), caption = caption}
    TriggerClientEvent('d-photomode:prepareCapture', src, s.id, c.id)
end)

local function settle(src, s, c, photo, phase, ok, message)
    c.phase, c.deadline = 'settling', os.time() + 10
    exports[resource]:settleDelivery(photo.id, s.owner, phase, function(error)
        if error or phase == 'uncertain' or phase == 'refund_pending' then print(('[d-photomode] Delivery %s needs staff reconciliation (%s).'):format(photo.id, phase)) end
        result(src, s, c, ok, message)
    end)
end
local function deliver(src, s, c, photo)
    if not captureValid(src, s, c) then result(src, s, c, false, 'Printing cancelled. No film was charged.') return end
    local film = Config.RequireFilm and PhotoInventory.film(src) or nil
    if Config.RequireFilm and not film then result(src, s, c, false, 'Film is no longer available. Nothing was charged.') return end
    c.phase, c.deadline = 'preparing_delivery', os.time() + 10
    exports[resource]:prepareDelivery(photo.id, s.owner, film or false, function(error)
        if error then result(src, s, c, false, 'The print could not be prepared. No film was charged.') return end
        if not captureValid(src, s, c) then
            exports[resource]:settleDelivery(photo.id, s.owner, 'cancelled', function() end)
            result(src, s, c, false, 'Printing cancelled. No film was charged.') return
        end
        -- No waits between these operations. QS enforces actual weight/slot capacity;
        -- snapshot readback verifies outcomes rather than trusting export truthiness.
        c.phase = 'delivering'
        local removed = film and PhotoInventory.removeFilm(src, film)
        if film and not removed then settle(src, s, c, photo, 'cancelled', false, 'Film changed before printing. Please try again.') return end
        if not captureValid(src, s, c) then
            local restored = not removed or PhotoInventory.refundFilm(src, film, s.owner)
            settle(src, s, c, photo, restored and 'refunded' or 'refund_pending', false, 'Printing was interrupted; staff can check photo ID ' .. photo.id)
            return
        end
        local added = PhotoInventory.addPhoto(src, photo)
        if added and not captureValid(src, s, c) then
            if not PhotoInventory.removePhoto(src, photo.id) then
                settle(src, s, c, photo, 'uncertain', false, 'Printing needs staff reconciliation: ' .. photo.id) return
            end
            local restored = not removed or PhotoInventory.refundFilm(src, film, s.owner)
            settle(src, s, c, photo, restored and 'refunded' or 'refund_pending', false, 'Printing was interrupted; staff can check photo ID ' .. photo.id)
            return
        end
        if added then settle(src, s, c, photo, 'delivered', true, 'Your photograph has been printed.') return end
        if removed and not PhotoInventory.refundFilm(src, film, s.owner) then
            settle(src, s, c, photo, 'refund_pending', false, 'No room to print or return film. Staff can recover your film using photo ID ' .. photo.id)
        else
            settle(src, s, c, photo, 'refunded', false, 'No room for the photograph. No film was charged.')
        end
    end)
end

RegisterNetEvent('d-photomode:captureReady', function(id, captureId)
    local src, s = source, sessions[source]
    local c = s and s.capture
    if not c or s.id ~= id or c.id ~= captureId or c.phase ~= 'waiting_ui' then return end
    if not captureValid(src, s, c) then result(src, s, c, false, 'Capture cancelled. No film was charged.') return end
    c.phase, c.deadline = 'uploading', os.time() + 45
    exports[resource]:capturePhotoToStorage(src, c.metadata, function(error, photo)
        if sessions[src] ~= s or s.capture ~= c or c.phase ~= 'uploading' then return end
        if error or type(photo) ~= 'table' then
            result(src, s, c, false, (type(error) == 'string' and error or 'Capture or upload failed.') .. ' No film was charged.') return
        end
        if not captureValid(src, s, c) then result(src, s, c, false, 'Printing cancelled. No film was charged.') return end
        c.phase, c.deadline = 'printing', os.time() + math.ceil(Config.PrintMilliseconds / 1000) + 10
        TriggerClientEvent('d-photomode:printing', src, id, captureId, Config.PrintMilliseconds)
        SetTimeout(Config.PrintMilliseconds, function() if c.phase == 'printing' then deliver(src, s, c, photo) end end)
    end, function(stage)
        if stage == 'captured' and sessions[src] == s and s.capture == c then
            TriggerClientEvent('d-photomode:captured', src, id, captureId)
        end
    end)
end)

local function useItem(src, item)
    if type(item) ~= 'table' or not PhotoInventory.ready(src) then return end
    local now = GetGameTimer()
    -- QS emits inventory:usedItem before its callback. Deduplicate those two
    -- supported entry paths without registering speculative inventory exports.
    if useTimes[src] and now - useTimes[src] < 250 then return end
    useTimes[src] = now
    if item.name == Config.Items.camera then
        if PhotoInventory.hasCamera(src) then TriggerClientEvent('d-photomode:useCamera', src) end
        return
    end
    local id = PhotoInventory.currentPhoto(src, item)
    if not id or (viewReads[src] and now - viewReads[src] < 750) then return end
    viewReads[src] = now
    exports[resource]:readPhotoDisplay(id, function(error, photo)
        if error or not photo or not PhotoInventory.find(src, Config.Items.photo, id) then return end
        viewedPhotos[src] = id
        TriggerClientEvent('d-photomode:viewPhoto', src, photo)
    end)
end
for _, itemName in ipairs({Config.Items.camera, Config.Items.photo}) do
    QBCore.Functions.CreateUseableItem(itemName, function(src, item) useItem(src, item) end)
end
-- The supplied QS UseItem.lua emits this trusted local event even when its
-- escrowed registry differs from QB's callback bridge. It is not a net event.
AddEventHandler('inventory:usedItem', function(name, src, item)
    if GetInvokingResource() ~= Config.InventoryResource then return end
    if name == Config.Items.camera or name == Config.Items.photo then useItem(src, item) end
end)

local function queueInventoryCheck(src)
    if inventoryChecks[src] or not (sessions[src] or viewedPhotos[src]) then return end
    inventoryChecks[src] = true
    SetTimeout(250, function()
        inventoryChecks[src] = nil
        if sessions[src] and not PhotoInventory.hasCamera(src) then stop(src, 'You no longer have your camera.') end
        if viewedPhotos[src] and not PhotoInventory.find(src, Config.Items.photo, viewedPhotos[src]) then
            viewedPhotos[src] = nil
            TriggerClientEvent('d-photomode:closePhoto', src)
        end
    end)
end
AddEventHandler('QBCore:Player:SetPlayerData', function(data) if type(data) == 'table' then queueInventoryCheck(data.source) end end)
AddEventHandler('QBCore:Server:OnPlayerUpdated', function(src, key) if key == 'items' or key == 'all' then queueInventoryCheck(src) end end)
AddEventHandler('qb-inventory:server:itemRemoved', function(src, name) if name == Config.Items.camera or name == Config.Items.photo then queueInventoryCheck(src) end end)
RegisterNetEvent('d-photomode:inventoryChanged', function() queueInventoryCheck(source) end)
RegisterNetEvent('d-photomode:closePhoto', function() viewedPhotos[source] = nil end)
AddEventHandler('onResourceStop', function(name)
    if name == resource or name == Config.InventoryResource or name == 'qb-core' or name == 'screencapture' then
        for src in pairs(sessions) do stop(src) end
        for src in pairs(viewedPhotos) do TriggerClientEvent('d-photomode:closePhoto', src) end
        viewedPhotos = {}
    end
end)

-- Confirmed refund failures can be retried from the server console, with a durable
-- pre-refund transition. Ambiguous prepared/refunding crash states are never replayed.
RegisterCommand('photomode_refund', function(src, args)
    if src ~= 0 then return end
    local id = args[1]
    if type(id) ~= 'string' then print('Usage: photomode_refund <photo UUID>') return end
    exports[resource]:readPhotoDelivery(id, function(error, journal)
        if error or not journal or journal.phase ~= 'refund_pending' or not journal.film then print('[d-photomode] No confirmed film refund is pending for this photo.') return end
        local player = QBCore.Functions.GetPlayerByCitizenId(journal.owner)
        if not player then print('[d-photomode] The film owner must be online for recovery.') return end
        exports[resource]:settleDelivery(id, journal.owner, 'refunding', function(transitionError)
            if transitionError then return end
            local restored = PhotoInventory.refundFilm(player.PlayerData.source, journal.film, journal.owner)
            exports[resource]:settleDelivery(id, journal.owner, restored and 'refunded' or 'refund_pending', function(saveError)
                print(saveError and '[d-photomode] Recovery needs reconciliation.' or restored and '[d-photomode] Film restored.' or '[d-photomode] Still no inventory capacity; refund remains pending.')
            end)
        end)
    end)
end, true)
