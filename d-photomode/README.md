# d-photomode · Dinsoh Development

Anchored RP photography for QB-Core. Version 0.2.2, staging release.

## FINI assessment
FINI's deployed camera policy is unknown. Scripted camera creation, local grading and DoF still need testing with FINI enabled on a normal player account. Anchoring reduces scope; it does not establish anticheat compatibility. No bypass, detection manipulation, whitelist integration or safety guarantee is included. Orbit controls are included but disabled by default; anchored-mode testing does not establish orbit compatibility. Access defaults to ACE restricted for staging; do not open access before QA.

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

Compose your normal gameplay camera before entry: with orbit disabled, position and heading remain anchored, with FOV (20–90° by default), roll (±15°), thirds/golden/center guides, letterbox ratios and 13 local filter choices. No player repositioning, collision changes, invisibility, spectator mode or freecam. Use your usual screenshot tool; there is no capture/upload service. For cinema bars in screenshots retain the overlay; fully clean screenshots use H. DoF/focus is optional, off by default and renderer dependent. Focus distance changes blur range only, independently of zoom; blur strength is adjustable when DoF is enabled. Unsupported grading can be removed from Config.Filters. Exposure and poses are not included: there is no reliable general-purpose exposure control or verified FINI allowance here.

Sessions last 180 seconds by default and starts are rate limited. Server validates online player, ACE/job access, death/laststand, on-foot state and displacement. Server checks active sessions once per second; client handles local death, movement, vehicle/ragdoll, timeout and resource stop. One session per player, no camera-coordinate broadcast, SQL or inventory effects. These checks do not secure a locally modified client or implement an anticheat.

### Zoom, filters and framing
Entry and Reset preserve the current gameplay camera FOV by default, avoiding an initial zoom jump. The starting value is included in the slider range when graphics settings put it outside configured bounds. Set `Fov.preserveGameplay = false` to use the configured default instead. Zoom is labeled in degrees; lower FOV magnifies the scene.

Camera contains orbit controls, zoom and roll; Look contains filters, intensity and optional DoF/focus/blur; Frame contains guides and letterboxing. There are 13 native looks including Natural, Cinema, black-and-white, vivid/muted, contrast, brightness and desaturated looks. Filter strength is adjustable and disabled for Natural. Only one native grade is active at a time; there is no arbitrary photo-editor effect stacking. Modifier names were verified against GTA timecycle data, not visually tested in this server. Remove any look incompatible with your graphics pack.

Guides are thirds, golden ratio and center cross. Letterbox/pillarbox masks frame 2.39:1, 1.85:1, 16:9 or square compositions without stretching the game view. They are preview overlays, not an exported image crop. H still hides all resource overlays. No camera-item, upload or print flow is included on main yet; the Polaroid branch tracks that integration.

## Player photography / constrained orbit (staging)
The owner reports the anchored build working in server testing. Orbit is a separate behavior requiring its own FINI-enabled test.

To test the new angles, keep ACE restricted and set `Config.Orbit.enabled = true` in `config.lua`, then restart `d-photomode`. The authorized player's UI gains Front / Left / Back / Right buttons and angle, distance and height sliders. It starts facing the player from the front; no phone or Rockstar Editor required. Angle is relative to the player's entry heading. Default distance limits are 1–3 m; height is -0.4 to +1.5 m relative to a target 0.7 m above the entry ped coordinate. FOV/roll/grades and overlay hiding still work. Reset returns to front at default distance/height.

The server supplies the anchor/heading/limits, and checks actual ped displacement as before. Camera translation is calculated only around that anchor; it never follows a moving player or permits world-coordinate input. The player is not teleported, frozen, hidden or posed. Collision line probes shorten the camera offset before obstructions; insufficient room or unavailable collision results end the session. Rechecks run every 250 ms while orbit is active to catch moving obstructions. These checks are not proof against all clipping/streaming artifacts; test interiors, vehicles, glass and nearby peds in game. Camera motion currently snaps to input rather than sweeping or interpolating through geometry. Probes and movement cost have not been profiled.

Set `Config.Orbit.enabled = false` and restart to restore the anchored-only workflow. Do not change FINI detections or claim orbit compatibility based on anchored test results.

## Cleanup and coexistence
Only the owned camera is destroyed. Active controls are suppressed without moving/freezing the ped. NUI focus and radar are restored on exit, with HUD suppression lasting only active frames. Camera DoF ends with camera destruction. No streaming focus, weather, time, ped pose or primary timecycle is changed. Entry refuses existing scripted cameras and timecycle effects; an owned extra grade is cleared on exit. Other resources starting camera/extra-grade effects during the session may conflict; coordinate them in staging. No universal effect-ownership API exists.

## Troubleshooting
Unavailable: the notification now reports the specific ACE, job, character, death/laststand or vehicle reason. ACE restrictions remain enabled by default. Grant `d-photomode.use` to an existing tester principal, or set `RequireAce = false` for public player access after QA. QB-Core admin status alone does not guarantee the ACE.

A QB-Core `global lib` notification error means its customized notification handler has no initialized ox_lib global in that resource. d-photomode now uses local GTA notices and does not call that handler. Other resources using it may still need QB-Core's own ox_lib integration repaired; starting ox_lib or importing it in d-photomode alone does not initialize QB-Core's Lua globals. Exit before retrying. Start requests have a five-second cooldown. If another screen effect or camera is active, finish it first. Missing blur: verify renderer/graphics settings and EnableDof; turn off if incompatible. Script errors: inspect client F8/server console and provide exact versions and reproduction steps.

## Validation
See TEST_PLAN.md. Cloud checks cover Lua parsing, mocked session logic and browser UI only. FiveM natives, deployed QB-Core, FINI, visual presets and renderer behavior are **not validated in game**. Idle/active resmon and concurrency cost: **not measured**. This version requires staging QA before production or a Tebex release.
