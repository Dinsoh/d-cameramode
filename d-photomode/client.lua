local state, pending, viewing = nil, false, false
local resource = GetCurrentResourceName()

local function closePhoto()
    if not viewing then return end
    viewing = false
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'closePhoto' })
end

local function cleanup(reason)
    closePhoto()
    local s = state
    state, pending = nil, false
    if not s then return end
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = 'close' })
    RenderScriptCams(false, false, 0, true, false)
    if s.cam and DoesCamExist(s.cam) then DestroyCam(s.cam, false) end
    if s.filter then ClearExtraTimecycleModifier() end
    DisplayRadar(s.radar)
    TriggerServerEvent('d-photomode:finish', s.id)
    if reason then TriggerEvent('QBCore:Notify', reason, 'primary') end
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
        SetCamDofStrength(s.cam, 0.5)
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
        TriggerEvent('QBCore:Notify', 'Finish the current screen effect before using photo mode.', 'error')
        return
    end
    local origin, position = GetEntityCoords(ped), GetGameplayCamCoord()
    if #(position - origin) > Config.MaxCameraDistance then
        TriggerServerEvent('d-photomode:finish', id) return
    end
    local s = { id = id, ped = ped, origin = origin, orbit = orbit, angle = 0.0,
        distance = orbit and orbit.distance.default, height = orbit and orbit.height.default, nextCollision = 0, rotation = GetGameplayCamRot(2),
        fov = Config.Fov.default, tilt = 0.0, dof = false, focus = 5.0,
        radar = not IsRadarHidden(), hidden = false, expires = GetGameTimer() + seconds * 1000 }
    state = s
    local ok, err = pcall(function()
        s.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', false)
        if s.cam == 0 then error('Camera creation failed') end
        SetCamCoord(s.cam, position.x, position.y, position.z)
        orbitPosition(s)
        apply(s)
        SetCamActive(s.cam, true)
        RenderScriptCams(true, false, 0, true, false)
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ action = 'open', fov = Config.Fov, tilt = Config.MaxTilt,
            filters = Config.Filters, dof = Config.EnableDof, hideKey = Config.HideKey, orbit = orbit or false })
    end)
    if not ok then
        cleanup(s.endReason or 'Photo mode could not start')
        if not s.endReason then print(('[%s] %s'):format(resource, err)) end
        return
    end
    CreateThread(function()
        local success, failure = xpcall(function()
            while state == s do
                Wait(0)
                if state ~= s then break end
                local current = PlayerPedId()
                if current ~= s.ped or IsEntityDead(current) or IsPedInAnyVehicle(current, true)
                    or IsPedRagdoll(current) or #(GetEntityCoords(current) - s.origin) > Config.MaxPedDisplacement
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
RegisterNetEvent('d-photomode:denied', function()
    pending = false
    TriggerEvent('QBCore:Notify', 'Photo mode is unavailable. Check permissions and player state.', 'error')
end)

RegisterCommand(Config.Command, function()
    if viewing then closePhoto() return end
    if state then cleanup() return end
    if pending then return end
    pending = true
    TriggerServerEvent('d-photomode:start')
    SetTimeout(5000, function() pending = false end)
end, false)
RegisterKeyMapping(Config.Command, 'Toggle photography mode', 'keyboard', Config.Key)
RegisterCommand('photomode_exit', function() cleanup() end, false)
RegisterKeyMapping('photomode_exit', 'Exit photography mode', 'keyboard', Config.ExitKey)
local function hide()
    if not state then return end
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
    if not s or type(data) ~= 'table' then cb({ ok = false }) return end
    local function number(value, lo, hi, fallback)
        local n = tonumber(value)
        if not n or n ~= n or n == math.huge or n == -math.huge then return fallback end
        return math.max(lo, math.min(hi, n))
    end
    s.fov = number(data.fov, Config.Fov.min, Config.Fov.max, s.fov)
    s.tilt = number(data.tilt, -Config.MaxTilt, Config.MaxTilt, s.tilt)
    s.focus = number(data.focus, 1.0, 50.0, s.focus)
    s.dof = Config.EnableDof and data.dof == true
    if s.orbit then
        s.angle = number(data.angle, -180.0, 180.0, s.angle)
        s.distance = number(data.distance, s.orbit.distance.min, s.orbit.distance.max, s.distance)
        s.height = number(data.height, s.orbit.height.min, s.orbit.height.max, s.height)
    end
    local index = number(data.filter, 1, #Config.Filters, 1)
    local preset = Config.Filters[math.floor(index)]
    if preset and preset.modifier then
        SetExtraTimecycleModifier(preset.modifier)
        SetExtraTimecycleModifierStrength(1.0)
        s.filter = true
    elseif s.filter then ClearExtraTimecycleModifier() s.filter = false end
    local ok = pcall(function() orbitPosition(s) apply(s) end)
    if not ok then cleanup(s.endReason or 'Photo controls could not be applied') end
    cb({ ok = ok })
end)
AddEventHandler('onResourceStop', function(name) if name == resource or name == 'qb-core' then cleanup() end end)

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
end)
RegisterNUICallback('closePhoto', function(_, cb) closePhoto() cb({ ok = true }) end)
