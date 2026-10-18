# Validation and staging QA · 0.3.0

Cloud verification covers the implemented logic, not a running GTA/FiveM server. The owner previously reported initial camera testing successful; new item/prop/capture/upload/print behavior has **not** yet been verified in the deployed server.

## Automated development checks

From the repository root, install the pinned optional test dependencies (`tests/requirements.txt`) outside the resource. No Python or browser dependency belongs on the FiveM server.

```sh
python3 -m pip install --target /workspace/.photomode-tools -r tests/requirements.txt
export PYTHONPATH=/workspace/.photomode-tools
python3 -m unittest discover -s tests -p 'test_client.py'
python3 -m unittest discover -s tests -p 'test_sessions.py'
python3 -m unittest discover -s tests -p 'test_polaroid.py'
python3 tests/test_ui.py
python3 tests/test_photo_viewer.py
node --test tests/test_storage.cjs tests/test_fivemanage.cjs tests/test_storage_bridge.cjs
node --check d-photomode/html/app.js
node --check d-photomode/html/photo.js
node --check d-photomode/storage.js
node --check d-photomode/fivemanage.js
```

Lua tests explicitly use `lupa.lua54`. Browser checks use `/usr/bin/chromium` and mocked FiveM NUI transport. Backend bridge tests exercise actual storage code and simulated screenshot-basic/HTTPS callbacks. They use test fixtures only, never a placeholder in a finished player photo.

Optional private vendor contract check:

```sh
QS_REFERENCE_DIR=/path/to/your/extracted/qs-inventory python3 -m unittest discover -s tests -p 'test_qs_reference.py'
```

That executes readable supplied QS add/remove/stack functions with framework doubles. Without that directory those two tests are skipped, not passed. The private QS source is not committed or included in the release.

Coverage: entry permissions and camera ownership, FOV preservation, focus/zoom independence, orbit bounds/collision failures, prop/focus cleanup, overlay-ready gating, replay/duplicate completions, full inventory/refund/recovery, inventory changes during printing, caption UTF-8/plain-text bounds, viewing ownership and transfers, orchestrator restart with retained records/items, local record/delivery-journal durability, malformed/failed/redirected provider responses, canonical URL checks, bounded uploads and cancelled late callbacks. Mocked network success does not verify a live media key or actual hosting.

## Required in-game matrix (pending)

Use staging with FINI enabled and a normal player account. Record server artifact, QB/QS/screenshot-basic versions, graphics mods, resolution, hardware, FiveManage configuration (names/status only), and actual FINI outcomes. Set the optional ACE gate for a restricted rollout if needed. Stop on an anticheat alert; do not suppress or bypass detections.

| Scenario | Expected result |
| --- | --- |
| Use camera item; F7/command without camera | Item opens mode; aliases cannot bypass possession |
| Camera prop with male/female peds and common outfits | Correct hand attachment/animation; nearby players see one prop; no ghost object |
| Entry/reset with normal/wide gameplay FOV | No forced zoom jump; Reset restores entry view |
| Focus/blur, all native looks, strength 0/1 | Focus independent of zoom; actual visual result reviewed for graphics mods |
| Camera/Look/Frame tabs; 720p/1080p/ultrawide | Controls usable; no clipping; guides/ratios aligned |
| Take photo; inspect final hosted image | Exact game view; no cursor/owned controls/flash baked into capture; unrelated HUD behavior documented |
| Upload succeeds; print finishes | One unique item, one film consumed, correct ID/URL/date/RP name/caption |
| Film disabled; no film; film removed before print | Config respected; no unauthorized mint/charge |
| Missing/invalid media key; API 401/403/429/5xx; timeout | Clear failure; no photo item or film charge; no credentials in logs/client |
| Inventory full/weight exceeded before delivery | No duplicate photo; exact film returned or confirmed pending refund with staff recovery ID |
| Recovery command repeated/unauthorized | Console-only; confirmed pending refund once; ambiguous states refused |
| Rapid shutter/item use; duplicate ready/completion | At most one capture/print per authorized attempt |
| Move/drop/store camera or photo while open | Event-driven possession recheck closes relevant mode/viewer |
| Death/downed/ragdoll, ped replacement, teleport, vehicle | Session ends; no stuck camera/prop/animation/NUI focus; pending capture cannot issue late |
| Escape during loading/capture/upload/printing | Clean cancellation; no late reward; check film/journal if interruption occurs at mutation boundary |
| Disconnect/reconnect/source-ID reuse mid-upload | No reward to a new character/source; no duplicated film/photo |
| Resource/QS/core stop/restart | All props/cameras/focus cleaned; retained photo still opens; orphan files handled conservatively |
| Use photo; change only client metadata URL | Server record wins; inventory ownership rechecked |
| Give photo to another player; stash/trunk/glovebox roundtrip | Same UUID/metadata preserved; current holder can reopen; former holder cannot request it |
| Server restart with real QS SQL save/reload | Same image/metadata opens and link works from another browser/Discord |
| Copy link; denied clipboard; Escape | Copy never consumes item; selectable URL fallback; focus restored |
| Captions containing markup/long Unicode | Plain text, correct character limit, no execution/errors |
| Several photographers and viewers | Independent visuals/items; no server-wide photo broadcast; upload cap enforced |
| FINI-enabled optional orbit and new prop/capture | Record actual outcomes; previous anchored success is not an orbit/prop guarantee |
| Idle/normal-active/concurrent profiling | Record actual client resmon and server profiler data; no fabricated zero-cost claims |

Back up `data/photos/` and relevant inventory persistence before intentional crash/recovery testing. File records and QS database saves are separate: inspect ambiguous journals/inventory before any manual reissue. Provider/account/manual deletion can break links despite non-expiring URLs and retention exemption.

Status: actual game captures, live FiveManage key/upload, deployed inventory SQL persistence, FINI compatibility and performance values are **pending / not measured**.
