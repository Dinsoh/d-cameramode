# Codex task — WTPRP cinematic camera

Read `AGENTS.md` first and inspect the supplied `wtp-banking` reference (especially `fxmanifest.lua`, `src/client/camera.lua`, and `src/config.lua`). Build a **new, standalone** FiveM resource named `d-photomode`, not a banking modification.

## Hard requirement: FINI compatibility, no bypasses
WTPRP uses FINI/FiniAC, which can flag freecam or noclip. Do **not** disable, spoof, evade, suppress, or whitelist FINI detections. No anticheat event manipulation or concealment. There is **no defensible 100% no-ban guarantee** without testing against the deployed FINI configuration. Before coding, identify which camera primitives FINI permits; if this cannot be verified, implement a safe **fixed/anchored camera MVP** and gate orbit/movement behind a disabled-by-default config option pending owner-approved FINI testing. Never silently enable a risky feature.

## Product
Make a polished photography mode for player screenshots and RP scenes. Use a small, elegant NUI overlay that hides cleanly for screenshots. Offer FOV/zoom, camera tilt, composition grid, cinematic bars, optional time-of-day-independent **local-only** color grading presets, exposure where supported, and optional native DoF/focus controls with graceful fallback. Provide configurable keybinds and a one-key exit. Use engine-supported visual effects; don't promise arbitrary Lightroom-like post-processing. Prefer a stationary, player-anchored camera; no spectator mode, map-wide flying, noclip, ped teleportation, invisibility, collision disabling, or unrestricted movement. Do not alter server weather/time or other players' visuals. Optional ped poses only if they don't introduce anticheat issues.

## Security and state
A server-issued short-lived session authorization is required to enter. Validate online status, rate limit starts, enforce one active session/player, session expiry, and server-controlled permission rules. Never treat NUI/client flags as security authority. For any optional movement, constrain distance relative to the **server-observed ped position**, clamp movement and angles, and immediately terminate on invalid conditions. Do not claim server-side checks can prevent all locally modified clients. Avoid networked cameras or broadcasting camera coordinates. Exit on death, teleport, vehicle state changes, resource stop, disconnect, timeout, or loss of permission where relevant. Restore all camera, HUD, focus, timecycle, DoF, controls, NUI focus, and pose state on every exit/error path.

## Performance and implementation
Target negligible idle overhead for 300–320 concurrent players. Lua 5.4, ox_lib where it simplifies implementation, QB-Core for identity/permissions; avoid inventory/database dependencies unless justified. No permanent per-frame threads while inactive. A frame loop is acceptable **only during active camera mode** for responsive controls. Cache handles; keep NUI messages minimal; no needless state bags, SQL writes, server broadcasts, props, polling, or huge libraries. Build readable, modular code with no placeholders or AI-generated filler. Match WTPRP's clean, understated UI taste; don't copy banking UI wholesale.

## Deliverables and proof
1. Brief FINI compatibility assessment with explicit unknowns, not a claim of guaranteed safety.
2. Standalone working resource (`fxmanifest.lua`, shared config, client/server Lua, minimal NUI), README and test plan.
3. Default **safe anchored mode**; clearly flag experimental features as disabled until tested with FINI.
4. Manual QA matrix with FINI enabled on a normal player account: enter/exit, death, disconnect, resource restart, movement/teleport, vehicle, screenshot, DoF on/off, rapid input, multiple users, and cleanup.
5. Report actual measured idle and active resmon values only after testing; otherwise mark **not measured**.

Do not proceed with anticheat-sensitive movement until compatibility is demonstrated. Ask for FINI documentation or owner-approved test results if needed.

Owner clarification: wtp-banking is visual UI reference only. Do not use its camera implementation. Developer branding: Dinsoh Development.
