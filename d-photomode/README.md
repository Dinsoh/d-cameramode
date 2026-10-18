# d-photomode · Dinsoh Development

Version 0.4.1 — inventory-based instant photography for We The People RP and QB-Core. Use a camera, frame the game view, capture it, and receive a unique photograph you can view, copy, give away or keep in supported QS storage. The camera controls from 0.2.x remain available.

Implemented against the supplied QS customization source and FiveManage's official V3 API. **Cloud tests pass; a real FiveM capture, live FiveManage authentication/upload, prop placement, QS database reload and FINI behavior still require staging QA.** Resmon/concurrency timings have not been measured. See [TEST_PLAN.md](TEST_PLAN.md).

## Requirements

- Current FiveM GTA V with OneSync/server entity natives and Lua 5.4.
- QB-Core and the supplied QS-Inventory QB integration (`item.info`, QB `PlayerData.items`, `AddItem`/`RemoveItem`). See [integration evidence](POLAROID_INTEGRATION.md).
- [screencapture](https://github.com/itschip/screencapture), including its native server `serverCapture` API. This resource calls `screencapture` directly; screenshot-basic is not required.
- A FiveManage **media upload** key and server HTTPS access to `api.fivemanage.com`. Players must be able to load `r2.fivemanage.com` images.

No phone, Rockstar Editor, fmsdk, new UI framework, new database table or separate ox_lib dependency is required. Existing QS dependencies still apply. The native prop represents the physical camera; the inventory artwork is not a new streamed 3D Polaroid model.

## Installation / upgrade

1. Stop the old copy and run only one version. Back up the existing resource and keep any existing `d-photomode/data/` directory. Copy the updated `d-photomode` resource into your resources folder.
2. Merge the entries in [install/items.lua](install/items.lua) **inside** `QBShared.Items` in `qb-core/shared/items.lua`. It is a table fragment, not a script to run. Do not replace the rest of your item list. The supplied QS QB bridge reads that list; `qs-inventory/shared/items.lua` is for its ESX mode.
3. Copy the three PNGs from `install/images/` into `qs-inventory/html/images/`, as specified by the supplied item definitions. Optional hover labels are in `install/metadata.lua`.
4. Use the updated `config.lua`, merging your tested FOV/orbit/job/key settings. Settings include `Items`, `Prop`, `Viewfinder`, film/capture/print options. The viewfinder defaults on even when upgrading an older config; use the supplied expanded orbit ranges for self portraits. Do not retain the old config unchanged. Camera/photo names must match the registered items; the photo must keep `unique = true` and `stack = false`. The supplied item entries disable decay/removal on breakage so collected photographs do not age away.
5. Configure a **rotated, private server-side** FiveManage media key. A server already using private `FIVEMANAGE_MEDIA_API_KEY` is supported without a duplicate binding. Otherwise add this in a private server config (replace the placeholder there):

   ```cfg
   set d_photomode_fivemanage_key "YOUR_ROTATED_MEDIA_KEY"
   set d_photomode_storage "fivemanage"
   ```

   Use `set`, never `setr` or `sets`. Do not put keys in shared Lua, NUI, a public repository or chat. LB Phone's own private Lua API table is not automatically a convar; this resource does not read its secret files. No key supplied in chat has been embedded in this resource.
6. Start in this order, preserving your existing QB/QS prerequisites:

   ```cfg
   ensure qb-core
   ensure qs-inventory
   ensure screencapture
   ensure d-photomode
   ```

7. Restart the core/inventory as appropriate to load the item definitions, then test on staging. Give the tester `polaroid_camera` and `polaroid_film` using your existing admin/shop tooling. This resource adds no shop, item-grant command or economy prices.

By default any eligible player **holding the camera** can use it (`RequireAce = false`). `/photomode` and F7 are convenience aliases and enforce the same possession check. For a restricted staging test set `RequireAce = true` and grant `d-photomode.use` to your tester principal. `AllowedJobs` optionally restricts camera use; photo owners can view their pictures independently of the photographer's job/ACE. Existing pictures are not consumed on view or copy.

## Taking and viewing photographs

If upgrading with an existing config, set `Config.Prop.model = 'prop_pap_camera_01'` and restart `d-photomode` to fix the unavailable-prop error.

Use the camera inventory item. It equips `prop_pap_camera_01` and opens a clean, fixed eye-level viewfinder. Move the mouse to aim, scroll to zoom, press Enter to take a photo, H for settings and Escape to put it away. Your own character/prop are hidden only from your view in this mode; other players still see the photographer. Movement/combat remain blocked. There are no flight controls.

In H → Camera, choose **Self portrait** to photograph yourself when `Orbit.enabled = true`. Switch **Hold camera pose** off for a natural stance; the prop is also hidden from your self portrait when the pose is off. Switching back to Camera restores your previous aiming direction. The pose can be enabled again without leaving the session.

Self-portrait controls include 360° orbit, 0.4–10 m distance and −2–6 m height relative to the orbit target (new defaults), with 0.1° angle/roll and 0.01 m distance/height steps. Arrow keys on a focused slider give the smallest steps. Mouse aiming in Self portrait adjusts orbit angle/height; scroll still adjusts the lens. Collision and the server-granted 13 m radius bound the orbit. Existing configs retain their own ranges until updated.

Aim, wheel zoom, roll and orbit sliders ease smoothly using frame-rate-independent response. Wheel steps become finer at longer zoom. The shutter freezes the current rendered framing and cancels pending easing, including if pressed mid-transition. Pitch reaches ±89°, roll ±45° and FOV 15–100°. In config, `Motion.response`, `zoomResponse` and `orbitResponse` control response speed (higher is quicker); `zoomStep` controls wheel increments. `Motion.enabled = false` disables easing. These are new defaults: merge the updated `Viewfinder`, `Motion`, `Fov`, `MaxTilt`, `Orbit` and `MaxCameraDistance` settings if retaining your config.

Look contains 13 native filters, adjustable strength and optional DoF/focus/blur. Frame contains thirds/golden/center guides, letterbox ratios and an optional caption.

Enter/Return or **Take photo** releases the cursor and hides all resource overlays. After two NUI frames the server requests an actual game-render screenshot. A shutter sound plays; a short flash happens only after the image has reached the server, so it is not baked into the photograph. A successful FiveManage upload triggers the printing effect and inventory delivery. Default film cost is one unit **per successfully printed photo**, not per failed attempt. Set `RequireFilm = false` to disable consumption.

H opens/closes settings without leaving the viewfinder; Escape exits. Key mappings are configurable in FiveM settings. Focused NUI shortcuts use the configured initial key names; use the on-screen buttons if a remapped game shortcut is intercepted by NUI. Death, displacement/teleport, vehicle/ragdoll changes, expiry, camera-item loss, disconnect and resource stop end the session and clean up the owned camera, prop, animation, grade and focus.

Use a photo inventory item to view that specific picture. The off-white Polaroid viewer shows the server-owned caption, photographer's RP name and date. **Copy Image Link** copies a permanent public image URL; anyone with that link can view it. If clipboard access is unavailable a selectable URL appears. No Copy Image/pixel button is offered because reliable pixel clipboard support has not been demonstrated in the deployed NUI. Escape closes the viewer. Transferring the item grants viewing to the new holder, not just its original photographer.

The default viewfinder starts at a consistent 70° FOV (1.0×), configured by `Viewfinder.fov`; it does not inherit third-person zoom. Capture keeps exactly the selected FOV and camera position. Reset returns to the starting lens. Setting `Viewfinder.enabled = false` restores the older panel-first mode and its `Fov.preserveGameplay` behavior. Focus distance affects blur only, not zoom. `EnableDof` is off by default because renderer/graphics mods can change its behavior. Filters use real GTA timecycle modifiers, with appearance pending your visual QA. Only one native grade is active at a time.

## FINI and framing limits

Self portrait is available through `Orbit.enabled` (enabled in this version following the owner’s orbit testing). Opening the camera still starts in the eye-level view. The owner reported the earlier anchored build working; the expanded orbit, local visibility and prop/capture changes still require staging tests with FINI enabled. No detection manipulation, bypass or no-ban guarantee is provided. These checks do not prove an unmodified client or replace FINI.

Orbit stays around the server-issued player anchor with bounded angles/distance/height and collision checks. There is no player teleportation, network invisibility, spectator mode, map-wide flying or player collision change. The eye-level view uses frame-local visibility for the photographer/prop only; self portraits show the character again. Ending the session naturally ends those per-frame visibility requests. The attached prop's collision alone is disabled. The initial camera position otherwise stays fixed. There are no camera-coordinate broadcasts.

The screenshot is the full native game-render view. Guide/letterbox masks are preview overlays and are intentionally hidden before capture; they do not crop the uploaded pixels. Native FOV/roll/grading/DoF appear according to screencapture and the renderer. Other resources' overlays and graphics effects are outside this resource's control. Entry refuses an existing scripted camera/timecycle effect; coordinate resources that start one during photo mode.

## Storage, privacy and recovery

See [POLAROID_INTEGRATION.md](POLAROID_INTEGRATION.md) for API references and the recovery contract. Images upload from the **server** to FiveManage V3 using the private Authorization header. Printed records accept only canonical HTTPS `r2.fivemanage.com` URLs without expiring query tokens; a custom-CDN response can use its canonical `originalUrl`. Uploads request `retentionExempt=true`. Keep the FiveManage account active and its retention/access settings appropriate; manual/provider deletion can still break a public link.

Each server-generated UUID has a record, local JPEG and delivery journal under `data/photos/`. **Back up and retain that folder across code updates and server moves.** Do not delete it or replace it with a clean Git checkout. There is no SQL migration: QS retains inventory items in its existing storage, while this resource retains photo records/files. Inventory metadata contains the public photo ID/URL/date/name; the viewer re-reads the authoritative record and checks possession. Private citizen IDs stay only in server records/journals.

Failed capture/upload does not charge film. Actual QS capacity is enforced when adding a photo. A failed print attempts to return the exact film metadata. If that refund cannot fit, the player receives a photo ID and a durable `refund_pending` journal is written. After the owner frees inventory space and is online, staff can run in the **server console**:

```text
photomode_refund <photo UUID>
```

That command handles confirmed pending refunds once. It refuses ambiguous `prepared`/`refunding` crash states and delivered records. Inventory mutations and filesystem journals cannot be one atomic transaction across QS's persistence; a process/power failure in that window requires staff reconciliation before reissuing anything. Do not blindly retry/refund an ambiguous record. Captures with uncertain upload completion or failed delivery can leave orphan media; do not delete records already referenced by printed items.

Uploads are bounded to four simultaneous requests by default (`set d_photomode_max_uploads "4"`), one capture per player, 4 MiB JPEG, quality 0.85, and a 1920×1080 maximum capture size with source aspect ratio preserved (no crop or added zoom). `CaptureCooldownSeconds`, `PrintMilliseconds`, `CaptionLength`, item names and film policy are in config. No per-frame inactive camera threads, continuous inventory polling, SQL per frame, photo broadcasts, telemetry or webhooks are added.

## Troubleshooting

- Camera unavailable: check item definitions, possession, QB character/death/vehicle state, job and optional ACE. Notifications use GTA natives, avoiding the customized QB `lib`-nil notification handler.
- Upload fails: ensure screencapture is started, the private media key is configured, and the server can reach the FiveManage API. The server logs sanitized HTTP errors such as 401/403/429 without keys or response bodies. A key's presence does not establish correct permissions.
- Missing image after reconnect: check `data/photos/` backup/permissions, the stored public URL, FiveManage retention/account status and the photo's actual `item.info.photoId`. Do not substitute a new URL in client metadata.
- Inventory full: free space and retry. Failed print film should be returned; if marked pending use the recovery process above.
- No blur or odd grade: disable DoF or remove the incompatible native filter. Verify graphics mods in staging.
- Prop position/animation or FINI alert: stop the test and inspect your server configuration. Adjust only supported prop placement/settings; never bypass detections.

## Capture diagnostics

The earlier `Capture storage failed (photo …)` message did not expose the failing operation. The ScreenCapture integration now explicitly requests `jpeg`: upstream can turn `jpg` into PNG bytes labelled as JPEG, which our signature checks reject. It uses the native one-argument server callback, not the screenshot-basic compatibility alias. New errors identify a stage (`allocate`, `decode`, `write-image`, `validate-image`, `upload`, `save-record`) and a safe error code/reason without printing private paths, keys or provider response bodies. `EACCES`/`EPERM` means a resource-folder permission or sandbox restriction; `ENOSPC` means the disk is full. Keep `data/photos` writable inside this resource. Do not add cross-resource filesystem permissions for this flow.

Record writes now use synced temporary files and same-folder rename, with per-record publication locks instead of hard links. JPEG flushing opens a writable handle for Windows compatibility. Those changes address portability problems, but the old generic warning alone cannot establish your server’s exact failure. If capture still fails after updating, report the new stage/code line. Do not include the media key.
