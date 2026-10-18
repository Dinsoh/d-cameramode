# d-photomode · Dinsoh Development

Anchored RP photography for QB-Core. Version 0.1.0, staging release.

## FINI assessment
FINI's deployed camera policy is unknown. Scripted camera creation, local grading and DoF still need testing with FINI enabled on a normal player account. Anchoring reduces scope; it does not establish anticheat compatibility. No bypass, detection manipulation, whitelist integration or safety guarantee is included. No movement/orbit code is shipped. Access defaults to ACE restricted for staging; do not open access before QA.

## Install
Requires current FiveM GTA V, OneSync server-side entity natives and QB-Core started first. Lua 5.4 runtime required. No database, inventory, ox_lib, banking or build pipeline required.

1. Copy `d-photomode` into your server resources directory.
2. Configure `config.lua`. Keep ACE restriction on during validation.
3. Add to server.cfg after QB-Core:

```cfg
ensure qb-core
ensure d-photomode
add_ace group.admin d-photomode.use allow
```

Use your existing principal/group assignments or grant a specific tester principal. QB-Core admin status alone does not create this ACE. To permit all players after successful QA, set `RequireAce = false`. `AllowedJobs` optionally restricts current QB-Core job names, independently of ACE.

## Controls and features
`/photomode` or F7 enters/exits. Escape exits. H hides/restores the entire overlay, including guides/bars. Change keyboard bindings in FiveM settings; config keys set initial defaults. When NUI is focused its hide shortcut uses the configured key name, so use the Hide overlay button if you rebind the game shortcut.

Compose your normal gameplay camera before entry: position and heading remain anchored, with FOV (20–80°), roll (±15°), thirds grid, cinema bars and local grade presets. No player repositioning, collision changes, invisibility, spectator mode or freecam. Use your usual screenshot tool; there is no capture/upload service. For cinema bars in screenshots retain the overlay; fully clean screenshots use H. DoF/focus is optional, off by default and renderer dependent. Unsupported grading can be removed from Config.Filters. Exposure, poses and camera motion are not included: there is no reliable general-purpose exposure control or verified FINI allowance here.

Sessions last 180 seconds by default and starts are rate limited. Server validates online player, ACE/job access, death/laststand, on-foot state and displacement. Server checks active sessions once per second; client handles local death, movement, vehicle/ragdoll, timeout and resource stop. One session per player, no camera-coordinate broadcast, SQL or inventory effects. These checks do not secure a locally modified client or implement an anticheat.

## Cleanup and coexistence
Only the owned camera is destroyed. Active controls are suppressed without moving/freezing the ped. NUI focus and radar are restored on exit, with HUD suppression lasting only active frames. Camera DoF ends with camera destruction. No streaming focus, weather, time, ped pose or primary timecycle is changed. Entry refuses existing scripted cameras and timecycle effects; an owned extra grade is cleared on exit. Other resources starting camera/extra-grade effects during the session may conflict; coordinate them in staging. No universal effect-ownership API exists.

## Troubleshooting
Unavailable: check QB-Core start order, ACE assignment, job filter, death/laststand and vehicle state. Exit before retrying. Start requests have a five-second cooldown. If another screen effect or camera is active, finish it first. Missing blur: verify renderer/graphics settings and EnableDof; turn off if incompatible. Script errors: inspect client F8/server console and provide exact versions and reproduction steps.

## Validation
See TEST_PLAN.md. Cloud checks cover Lua parsing, mocked session logic and browser UI only. FiveM natives, deployed QB-Core, FINI, visual presets and renderer behavior are **not validated in game**. Idle/active resmon and concurrency cost: **not measured**. This version requires staging QA before production or a Tebex release.
