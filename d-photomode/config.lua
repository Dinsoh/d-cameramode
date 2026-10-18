Config = {
    Command = 'photomode',
    CaptureKey = 'RETURN',
    InventoryResource = 'qs-inventory',
    Items = { camera = 'polaroid_camera', photo = 'polaroid_photo', film = 'polaroid_film' },
    RequireFilm = true,
    CaptureCooldownSeconds = 10,
    PrintMilliseconds = 1800,
    CaptionLength = 80,
    -- Fixed eye-level view; no flight or movement controls. H opens settings.
    Viewfinder = { enabled = true, fov = 70.0, sensitivity = 8.0 },
    Prop = { model = 'prop_pap_camera_01', bone = 28422,
        offset = { x = 0.0, y = 0.0, z = 0.0 }, rotation = { x = 0.0, y = 0.0, z = 0.0 },
        dictionary = 'amb@world_human_paparazzi@male@base', animation = 'base' },
    Key = 'F7',
    HideKey = 'H',
    ExitKey = 'ESCAPE',
    SessionSeconds = 180,
    StartCooldownSeconds = 5,
    MaxPedDisplacement = 1.5,
    MaxCameraDistance = 8.0,
    Fov = { min = 20.0, max = 90.0, default = 60.0, preserveGameplay = true },
    MaxTilt = 15.0,
    FilterStrength = 0.65,
    -- Self portraits stay inside this bounded orbit; verify the expanded range with FINI.
    Orbit = { enabled = true, distance = { min = 0.5, max = 6.0, default = 2.0 },
        height = { min = -1.0, max = 3.0, default = 0.2 }, targetHeight = 0.7 },
    EnableDof = false, -- renderer dependent; validate with your graphics settings
    -- Camera ownership is the default access gate. Set true for an ACE-only staging test.
    RequireAce = false,
    Ace = 'd-photomode.use',
    AllowedJobs = {}, -- empty means any job; server checks current QB-Core job
    -- Native modifier names verified against GTA timecycle data. Appearance still
    -- depends on weather/graphics mods; this does not change server weather/time.
    Filters = {
        { label = 'Natural', modifier = false },
        { label = 'Cinema', modifier = 'cinema' },
        { label = 'Soft cinema', modifier = 'cinema_001' },
        { label = 'Black & white', modifier = 'MP_corona_heist_BW' },
        { label = 'Night monochrome', modifier = 'MP_corona_heist_BW_night' },
        { label = 'Vivid', modifier = 'rply_saturation' },
        { label = 'Muted', modifier = 'rply_saturation_neg' },
        { label = 'High contrast', modifier = 'rply_contrast' },
        { label = 'Low contrast', modifier = 'rply_contrast_neg' },
        { label = 'Brighter', modifier = 'rply_brightness' },
        { label = 'Darker', modifier = 'rply_brightness_neg' },
        { label = 'Cool desaturated', modifier = 'hud_def_desat_cold' },
        { label = 'Neutral desaturated', modifier = 'hud_def_desat_Neutral' }
    }
}
