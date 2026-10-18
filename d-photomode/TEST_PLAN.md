# Staging QA · FINI enabled

Owner reports initial anchored testing successful; individual rows below have no recorded detailed results. All new orbit rows are pending. Use a normal player account with explicit test ACE, deployed QB-Core and FINI enabled. Record artifact/resource versions, graphics mods, resolution, hardware, FINI policy/results, and client/server logs. Do not suppress or bypass detections. Stop testing sensitive features on an alert and seek supported FINI guidance.

| Check | Expected |
| --- | --- |
| Entry without ACE / wrong job / missing QB player | Denied; no camera or focus |
| On-foot entry and Escape/F7/command exit | Single anchored camera; correct gameplay camera/radar/focus restored |
| Rapid starts, repeated NUI input, old finish event | No duplicate session; current session survives stale finish |
| Hide/restore and screenshot | Entire overlay hides; controls can be restored; no upload |
| Orbit disabled / forged NUI orbit values | Anchored camera unchanged; orbit section absent |
| Orbit enabled, normal test ACE, each preset | Front/left/back/right frame the player; no ped motion |
| Angle, distance/height extremes, malformed numeric input | Session bounds enforced; reset restores default front |
| Tight interior, wall, glass, nearby ped/vehicle, moving blocker | Offset shortens or session ends; no camera stuck beyond obstruction |
| Orbit + teleport/death/vehicle/expiry/restart | Existing cleanup paths still work |
| FINI-enabled orbit entry, presets, slider changes, repeated starts | Record actual deployed FINI outcome; stop on alert |
| Entry/reset with wide/normal gameplay FOV | No initial zoom jump; Reset returns to entry view |
| Focus distance/blur strength with DoF enabled | Blur changes without changing zoom |
| All 13 filters, intensity 0/1, return to Natural | Local grade changes; owned effect clears; no stale grade |
| Camera/Look/Frame tabs, all guides/ratios, hidden overlay | Compact UI; geometry aligned; H hides all |
| FOV/roll limits, invalid input | Bounded values; no camera translation |
| Grid/bars/reset and 720p/1080p/ultrawide | Correct alignment; controls fit; reset works |
| Each grade, existing effect before entry | Local grade only; existing effect refuses entry |
| DoF off/on and focus at near/far limits | No error; fallback is disabling DoF |
| Death/laststand, ragdoll, teleport/movement | Mode ends; no stuck input or effect |
| Enter vehicle / external vehicle placement | Mode ends; no stuck camera |
| Permission/job revoked and timeout | Server ends session within its next check |
| Disconnect/reconnect, resource restart/stop, QB-Core stop | Sessions/focus/camera/effects cleaned; reentry works |
| Multiple players / simultaneous starts | Independent cameras and visuals; no broadcast |
| Idle/active/stress profiling | Record actual client resmon and server profiler; no fabricated zero-cost claims |

Development checks from repository root:

```sh
# Optional development dependencies only; never install on the FiveM server.
python3 -m pip install --target /workspace/.photomode-tools lupa==2.8 playwright==1.62.0
PYTHONPATH=/workspace/.photomode-tools python3 tests/test_sessions.py
PYTHONPATH=/workspace/.photomode-tools python3 tests/test_client.py
PYTHONPATH=/workspace/.photomode-tools python3 tests/test_ui.py
node --check d-photomode/html/app.js
```

UI harness uses /usr/bin/chromium and mocked NUI transport. Session harness executes server.lua with mocked QB-Core/FiveM natives. Neither replaces deployed integration testing. Consumer ZIP excludes development tests.
