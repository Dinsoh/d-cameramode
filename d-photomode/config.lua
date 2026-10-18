Config = {
    Command = 'photomode',
    Key = 'F7',
    HideKey = 'H',
    ExitKey = 'ESCAPE',
    SessionSeconds = 180,
    StartCooldownSeconds = 5,
    MaxPedDisplacement = 1.5,
    MaxCameraDistance = 5.0,
    Fov = { min = 20.0, max = 90.0, default = 60.0, preserveGameplay = true },
    MaxTilt = 15.0,
    FilterStrength = 0.65,
    -- Enable only for owner-approved FINI staging tests; anchored tests do not verify orbit.
    Orbit = { enabled = false, distance = { min = 1.0, max = 3.0, default = 2.0 },
        height = { min = -0.4, max = 1.5, default = 0.2 }, targetHeight = 0.7 },
    EnableDof = false, -- renderer dependent; validate with your graphics settings
    -- ACE restricted by default for staged FINI testing. Set false for public use after QA.
    RequireAce = true,
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
