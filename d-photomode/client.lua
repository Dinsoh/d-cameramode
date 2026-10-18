local state, pending, viewing = nil, false, false
local resource = GetCurrentResourceName()

local function closePhoto()
    if not viewing then return end
    viewing = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'closePhoto' })
    TriggerServerEvent('d-photomode:closePhoto')
end

-- Resource-local notification: some customized QB-Core handlers assume an
-- initialized ox_lib global. These native notices need neither QB UI nor ox_lib.
local function notify(message)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

local function cleanup(reason)
    closePhoto()
    local s = state
    state, pending = nil, false
    if not s then return end
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close' })
    if s.cam and DoesCamExist(s.cam) then
        RenderScriptCams(false, false, 0, true, false)
        DestroyCam(s.cam, false)
    end
    if s.prop and DoesEntityExist(s.prop) then DeleteEntity(s.prop) end
    if s.pose then StopAnimTask(s.ped, Config.Prop.dictionary, Config.Prop.animation, 1.0) end
    if s.model then SetModelAsNoLongerNeeded(s.model) end
    if s.dictionary then RemoveAnimDict(s.dictionary) end
    if s.filter then ClearExtraTimecycleModifier() end
    DisplayRadar(s.radar)
    TriggerServerEvent('d-photomode:finish', s.id)
    if reason then notify(reason) end
end

local function equipCamera(s)
    local hash = GetHashKey(Config.Prop.model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then error('Camera prop is unavailable') end
    s.model, s.dictionary = hash, Config.Prop.dictionary
    RequestModel(hash)
    RequestAnimDict(s.dictionary)
    local deadline = GetGameTimer() + 5000
    while state == s and (not HasModelLoaded(hash) or not HasAnimDictLoaded(s.dictionary)) do
        if GetGameTimer() >= deadline then error('Camera assets timed out') end
        Wait(0)
    end
    if state ~= s then return false end
    local position = GetEntityCoords(s.ped)
    s.prop = CreateObject(hash, position.x, position.y, position.z, true, true, false)
    if s.prop == 0 then error('Camera prop could not be created') end
    SetEntityCollision(s.prop, false, false) -- attached prop only; never the player
    local offset, rotation = Config.Prop.offset, Config.Prop.rotation
    AttachEntityToEntity(s.prop, s.ped, GetPedBoneIndex(s.ped, Config.Prop.bone),
        offset.x, offset.y, offset.z, rotation.x, rotation.y, rotation.z, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(hash)
    s.model = nil
    TaskPlayAnim(s.ped, s.dictionary, Config.Prop.animation, 8.0, -8.0, -1, 49, 0.0, false, false, false)
    s.pose = true
    TriggerServerEvent('d-photomode:prop', s.id, NetworkGetNetworkIdFromEntity(s.prop))
    return true
end

-- Server grant supplies the anchor and limits; NUI never supplies world coordinates.
local function orbitPosition(s)
    local o = s.orbit
    if not o then return end
    local angle = math.rad(o.heading + s.angle)
    local target = vector3(o.origin.x, o.origin.y, o.origin.z + o.targetHeight)
    local desired = target + vector3(-math.sin(angle) * s.distance, math.cos(angle) * s.distance, s.height)
    local anchor = vector3(o.origin.x, o.origin.y, o.origin.z)
    if #(desired - anchor) > o.maxDistance then error('Camera exceeds session radius') end
    -- Ignore the photographed ped, but test world, vehicles, objects and other peds.
    -- Synchronous probe runs on input and at 4 Hz while active, never while idle.
    local probe = StartExpensiveSynchronousShapeTestLosProbe(target.x, target.y, target.z,
        desired.x, desired.y, desired.z, 511, s.ped, 7)
    local status, hit, endpoint = GetShapeTestResult(probe)
    if status ~= 2 then error('Camera collision check unavailable') end
    local position = desired
    if hit == 1 or hit == true then
        local delta = endpoint - target
        local length = #delta
        if length < 0.5 then
            s.endReason = 'Not enough room for photography'
            error(s.endReason)
        end
        position = target + delta * ((length - 0.2) / length)
    end
    local direction = target - position
    local horizontal = math.sqrt(direction.x * direction.x + direction.y * direction.y)
    SetCamCoord(s.cam, position.x, position.y, position.z)
    s.rotation = { x = math.deg(math.atan(direction.z, horizontal)),
        z = math.deg(math.atan(-direction.x, direction.y)) }
end

local function apply(s)
    SetCamFov(s.cam, s.fov)
    SetCamRot(s.cam, s.rotation.x, s.tilt, s.rotation.z, 2)
    SetCamUseShallowDofMode(s.cam, s.dof)
    if s.dof then
        SetCamNearDof(s.cam, math.max(0.1, s.focus - 1.0))
        SetCamFarDof(s.cam, s.focus + 1.0)
        SetCamDofStrength(s.cam, s.dofStrength)
    end
end

RegisterNetEvent('d-photomode:grant', function(id, seconds, orbit)
    if not pending or state then TriggerServerEvent('d-photomode:finish', id) return end
    pending = false
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedInAnyVehicle(ped, true) or IsGameplayCamRendering() == false then
        TriggerServerEvent('d-photomode:finish', id) return
    end
    -- Never take over another resource's grade. User can retry once it has finished.
    if GetTimecycleModifierIndex() ~= -1 or GetExtraTimecycleModifierIndex() ~= -1 then
        TriggerServerEvent('d-photomode:finish', id)
        notify('Finish the current screen effect before using photo mode.')
        return
    end
    local origin, position = GetEntityCoords(ped), GetGameplayCamCoord()
    if #(position - origin) > Config.MaxCameraDistance then
        TriggerServerEvent('d-photomode:finish', id) return
    end
    local entryFov = (Config.Fov.preserveGameplay ~= false) and GetGameplayCamFov() or Config.Fov.default
    if type(entryFov) ~= 'number' or entryFov ~= entryFov or entryFov <= 0 or entryFov > 130 then
        entryFov = Config.Fov.default
    end
    -- Include the entry view even when graphics/FOV settings exceed the configured
    -- slider range, so starting/resetting photo mode never introduces a zoom jump.
    local fovBounds = { min = math.min(Config.Fov.min, entryFov),
        max = math.max(Config.Fov.max, entryFov), default = entryFov }
    local s = { id = id, ped = ped, origin = origin, orbit = orbit, angle = 0.0,
        distance = orbit and orbit.distance.default, height = orbit and orbit.height.default, nextCollision = 0, rotation = GetGameplayCamRot(2),
        fov = entryFov, fovBounds = fovBounds, tilt = 0.0, dof = false, focus = 5.0,
        strength = Config.FilterStrength or 0.65, dofStrength = 0.5,
        radar = not IsRadarHidden(), hidden = false, expires = GetGameTimer() + seconds * 1000 }
    state = s
    local ok, err = pcall(function()
        if not equipCamera(s) then return end
        if not IsGameplayCamRendering() then error('Another camera is active') end
        s.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', false)
        if s.cam == 0 then error('Camera creation failed') end
        SetCamCoord(s.cam, position.x, position.y, position.z)
        orbitPosition(s)
        apply(s)
        SetCamActive(s.cam, true)
        RenderScriptCams(true, false, 0, true, false)
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ action = 'open', fov = fovBounds, strength = Config.FilterStrength or 0.65, tilt = Config.MaxTilt,
            filters = Config.Filters, dof = Config.EnableDof, hideKey = Config.HideKey, captureKey = Config.CaptureKey, captionLength = Config.CaptionLength, orbit = orbit or false })
    end)
    if not ok then
        cleanup(s.endReason or 'Photo mode could not start')
        if not s.endReason then print(('[%s] %s'):format(resource, err)) end
        return
    end
    if state ~= s then return end
    CreateThread(function()
        local success, failure = xpcall(function()
            while state == s do
                Wait(0)
                if state ~= s then break end
                local current = PlayerPedId()
                if current ~= s.ped or IsEntityDead(current) or IsPedInAnyVehicle(current, true)
                    or IsPedRagdoll(current) or not DoesEntityExist(s.prop) or #(GetEntityCoords(current) - s.origin) > Config.MaxPedDisplacement
                    or GetGameTimer() >= s.expires then cleanup() break end
                if s.orbit and GetGameTimer() >= s.nextCollision then
                    orbitPosition(s)
                    apply(s)
                    s.nextCollision = GetGameTimer() + 250
                end
                -- Block movement/combat only while active. No entity freezing or teleportation.
                DisableAllControlActions(0)
                EnableControlAction(0, 249, true) -- voice
                HideHudAndRadarThisFrame()
                if s.dof then SetUseHiDof() end
            end
        end, debug.traceback)
        if not success then
            cleanup(s.endReason or 'Photo mode ended')
            if not s.endReason then print(failure) end
        end
    end)
end)

RegisterNetEvent('d-photomode:stop', function(reason) cleanup(reason) end)
RegisterNetEvent('d-photomode:denied', function(reason)
    pending = false
    notify(type(reason) == 'string' and reason or 'Photo mode is unavailable. Check permissions and player state.')
end)

local function requestStart()
    if viewing then closePhoto() return end
    if state then cleanup() return end
    if pending then return end
    pending = true
    TriggerServerEvent('d-photomode:start')
    SetTimeout(5000, function() pending = false end)
end
RegisterCommand(Config.Command, requestStart, false)
RegisterNetEvent('d-photomode:useCamera', function()
    if source == 65535 and not state and not pending then requestStart() end
end)
RegisterKeyMapping(Config.Command, 'Toggle photography mode', 'keyboard', Config.Key)
RegisterCommand('photomode_exit', function() cleanup() end, false)
RegisterKeyMapping('photomode_exit', 'Exit photography mode', 'keyboard', Config.ExitKey)
local function hide()
    if not state or state.captureRequested or state.captureId then return end
    state.hidden = not state.hidden
    SendNUIMessage({ action = 'hidden', hidden = state.hidden })
    SetNuiFocus(not state.hidden, not state.hidden)
    SetNuiFocusKeepInput(false)
end
RegisterCommand('photomode_hide', hide, false)
RegisterKeyMapping('photomode_hide', 'Hide photo overlay', 'keyboard', Config.HideKey)

RegisterNUICallback('close', function(_, cb) cleanup() cb({ ok = true }) end)
RegisterNUICallback('hide', function(_, cb) hide() cb({ ok = true }) end)
RegisterNUICallback('update', function(data, cb)
    local s = state
    if not s or s.captureRequested or s.captureId or type(data) ~= 'table' then cb({ ok = false }) return end
    local function number(value, lo, hi, fallback)
        local n = tonumber(value)
        if not n or n ~= n or n == math.huge or n == -math.huge then return fallback end
        return math.max(lo, math.min(hi, n))
    end
    s.fov = number(data.fov, s.fovBounds.min, s.fovBounds.max, s.fov)
    s.tilt = number(data.tilt, -Config.MaxTilt, Config.MaxTilt, s.tilt)
    s.focus = number(data.focus, 1.0, 50.0, s.focus)
    s.strength = number(data.strength, 0.0, 1.0, s.strength)
    s.dofStrength = number(data.dofStrength, 0.0, 1.0, s.dofStrength)
    s.dof = Config.EnableDof and data.dof == true
    if s.orbit then
        s.angle = number(data.angle, -180.0, 180.0, s.angle)
        s.distance = number(data.distance, s.orbit.distance.min, s.orbit.distance.max, s.distance)
        s.height = number(data.height, s.orbit.height.min, s.orbit.height.max, s.height)
    end
    local index = number(data.filter, 1, #Config.Filters, 1)
    local preset = Config.Filters[math.floor(index)]
    local ok = pcall(function()
        if preset and preset.modifier then
            if s.modifier ~= preset.modifier then SetExtraTimecycleModifier(preset.modifier) end
            SetExtraTimecycleModifierStrength(s.strength)
            s.modifier, s.filter = preset.modifier, true
        elseif s.filter then
            ClearExtraTimecycleModifier()
            s.modifier, s.filter = nil, false
        end
        orbitPosition(s)
        apply(s)
    end)
    if not ok then cleanup(s.endReason or 'Photo controls could not be applied') end
    cb({ ok = ok })
end)
AddEventHandler('onResourceStop', function(name) if name == resource or name == 'qb-core' or name == Config.InventoryResource then cleanup() end end)

-- This display event is for the authoritative inventory/photo-record handler only.
-- No client request to view by ID is registered until inventory ownership can be checked.
RegisterNetEvent('d-photomode:viewPhoto', function(photo)
    if source ~= 65535 or type(photo) ~= 'table' or type(photo.id) ~= 'string'
        or type(photo.url) ~= 'string' or not photo.url:match('^https://[%w%.%-]+/') then return end
    cleanup()
    viewing = true
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'photo', photo = photo })
    CreateThread(function()
        while viewing do
            Wait(250)
            if IsEntityDead(PlayerPedId()) then closePhoto() end
        end
    end)
end)
RegisterNUICallback('closePhoto', function(_, cb) closePhoto() cb({ ok = true }) end)

RegisterNetEvent('d-photomode:closePhoto', function() if source == 65535 then closePhoto() end end)
RegisterNUICallback('capture', function(data, cb)
    local s = state
    if not s or s.captureRequested or s.captureId then cb({ok = false}) return end
    s.captureRequested = true
    TriggerServerEvent('d-photomode:capture', s.id, type(data) == 'table' and data.caption or '')
    SetTimeout(6000, function()
        if state == s and s.captureRequested and not s.captureId then
            s.captureRequested = false
            SendNUIMessage({action = 'captureResult', ok = false, message = 'The camera did not respond. Try again.', hidden = s.hidden})
        end
    end)
    cb({ok = true})
end)
RegisterNetEvent('d-photomode:prepareCapture', function(id, captureId)
    local s = state
    if source ~= 65535 or not s or s.id ~= id or not s.captureRequested or s.captureId then return end
    s.captureId, s.captureRequested = captureId, false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({action = 'prepareCapture', id = captureId})
end)
RegisterNUICallback('captureReady', function(data, cb)
    local s = state
    if not s or not s.captureId or type(data) ~= 'table' or data.id ~= s.captureId then cb({ok = false}) return end
    if not s.captureReady then
        s.captureReady = true
        PlaySoundFrontend(-1, 'Camera_Shoot', 'Phone_SoundSet_Default', true)
        TriggerServerEvent('d-photomode:captureReady', s.id, s.captureId)
    end
    cb({ok = true})
end)
RegisterNetEvent('d-photomode:captured', function(id, captureId)
    if source == 65535 and state and state.id == id and state.captureId == captureId then
        SendNUIMessage({action = 'captured'})
    end
end)
RegisterNetEvent('d-photomode:printing', function(id, captureId, duration)
    if source == 65535 and state and state.id == id and state.captureId == captureId then
        SendNUIMessage({action = 'printing', duration = duration})
    end
end)
RegisterNetEvent('d-photomode:captureResult', function(id, captureId, ok, message)
    local s = state
    if source ~= 65535 or not s or s.id ~= id or (s.captureId and captureId ~= s.captureId) then return end
    s.captureId, s.captureRequested, s.captureReady = nil, false, false
    SendNUIMessage({action = 'captureResult', ok = ok, message = message, hidden = s.hidden})
    SetNuiFocus(not s.hidden, not s.hidden)
    SetNuiFocusKeepInput(false)
end)
RegisterCommand('photomode_capture', function()
    if state and not state.captureId and not state.captureRequested then SendNUIMessage({action = 'requestCapture'}) end
end, false)
RegisterKeyMapping('photomode_capture', 'Take Polaroid photograph', 'keyboard', Config.CaptureKey)

-- React to inventory changes; never run an inventory-polling frame loop.
for _, event in ipairs({'qs-inventory:client:updateSlots', 'qs-inventory:client:UpdatePlayerInventory', 'QBCore:Player:SetPlayerData', 'QBCore:Client:OnPlayerUpdated'}) do
    RegisterNetEvent(event, function()
        if state or viewing then TriggerServerEvent('d-photomode:inventoryChanged') end
    end)
end
