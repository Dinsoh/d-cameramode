Config = {
    Command = 'photomode',
    Key = 'F7',
    HideKey = 'H',
    ExitKey = 'ESCAPE',
    SessionSeconds = 180,
    StartCooldownSeconds = 5,
    MaxPedDisplacement = 1.5,
    MaxCameraDistance = 5.0,
    Fov = { min = 20.0, max = 80.0, default = 50.0 },
    MaxTilt = 15.0,
    EnableDof = false, -- renderer dependent; validate with your graphics settings
    -- ACE restricted by default for staged FINI testing. Set false for public use after QA.
    RequireAce = true,
    Ace = 'd-photomode.use',
    AllowedJobs = {}, -- empty means any job; server checks current QB-Core job
    Filters = {
        { label = 'Natural', modifier = false },
        { label = 'Soft', modifier = 'cinema' },
        { label = 'Monochrome', modifier = 'NG_blackout' }
    }
}
