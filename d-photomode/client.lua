local state, pending = nil, false
local resource = GetCurrentResourceName()

local function cleanup(reason)
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

RegisterNetEvent('d-photomode:grant', function(id, seconds)
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
    local s = { id = id, ped = ped, origin = origin, rotation = GetGameplayCamRot(2),
        fov = Config.Fov.default, tilt = 0.0, dof = false, focus = 5.0,
        radar = not IsRadarHidden(), hidden = false, expires = GetGameTimer() + seconds * 1000 }
    state = s
    local ok, err = pcall(function()
        s.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', false)
        if s.cam == 0 then error('Camera creation failed') end
        SetCamCoord(s.cam, position.x, position.y, position.z)
        apply(s)
        SetCamActive(s.cam, true)
        RenderScriptCams(true, false, 0, true, false)
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({ action = 'open', fov = Config.Fov, tilt = Config.MaxTilt,
            filters = Config.Filters, dof = Config.EnableDof, hideKey = Config.HideKey })
    end)
    if not ok then cleanup('Photo mode could not start') print(('[%s] %s'):format(resource, err)) return end
    CreateThread(function()
        local success, failure = xpcall(function()
            while state == s do
                Wait(0)
                if state ~= s then break end
                local current = PlayerPedId()
                if current ~= s.ped or IsEntityDead(current) or IsPedInAnyVehicle(current, true)
                    or IsPedRagdoll(current) or #(GetEntityCoords(current) - s.origin) > Config.MaxPedDisplacement
                    or GetGameTimer() >= s.expires then cleanup() break end
                -- Block movement/combat only while active. No entity freezing or teleportation.
                DisableAllControlActions(0)
                EnableControlAction(0, 249, true) -- voice
                HideHudAndRadarThisFrame()
                if s.dof then SetUseHiDof() end
            end
        end, debug.traceback)
        if not success then cleanup('Photo mode ended') print(failure) end
    end)
end)

RegisterNetEvent('d-photomode:stop', function(reason) cleanup(reason) end)
RegisterNetEvent('d-photomode:denied', function()
    pending = false
    TriggerEvent('QBCore:Notify', 'Photo mode is unavailable. Check permissions and player state.', 'error')
end)

RegisterCommand(Config.Command, function()
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
    local index = number(data.filter, 1, #Config.Filters, 1)
    local preset = Config.Filters[math.floor(index)]
    if preset and preset.modifier then
        SetExtraTimecycleModifier(preset.modifier)
        SetExtraTimecycleModifierStrength(1.0)
        s.filter = true
    elseif s.filter then ClearExtraTimecycleModifier() s.filter = false end
    local ok = pcall(apply, s)
    if not ok then cleanup('Photo controls could not be applied') end
    cb({ ok = ok })
end)
AddEventHandler('onResourceStop', function(name) if name == resource or name == 'qb-core' then cleanup() end end)
