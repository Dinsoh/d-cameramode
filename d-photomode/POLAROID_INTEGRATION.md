# Polaroid integration — work in progress

This branch prepares a Polaroid viewer and a screenshot-basic/local-storage backend. It does **not** yet deliver camera usable items, film transactions, printing rewards, or ownership-checked inventory viewing. No item definitions, inventory exports or success semantics have been guessed. Existing photography remains available. Do not deploy this branch as a completed Polaroid system.

## Prerequisites still needed

- The installed QS-Inventory version and its supported usable-item, inventory lookup, add/remove, capacity, slot and unique metadata APIs. Provide relevant unencrypted integration/customization files or version-matched official documentation. Confirm whether per-item metadata is `info` or another field and how it survives transfers/storage.
- The owner confirms FiveManage as the existing host. Its upload API/integration is not available in this checkout, and the official docs domain is inaccessible from this cloud environment. Provide the supported server-upload docs or the relevant LB Phone upload integration with credentials redacted. Do not paste API keys. FiveManage is the target provider; the local backend below is only a prepared fallback, not a replacement selected for the live server.

Once those are known, connect camera ownership to session entry/capture, implement single-use capture leases, overlay-hide acknowledgement before server capture, film/print delivery with recovery and capacity handling, item ownership checks on view, prop/animation cleanup and item assets. These are outstanding work, not completed integrations. The pending end-to-end QA is: use item → frame → capture/upload → print → receive item → view/copy → transfer/store → reopen after restart, including failures and duplicates.

## Implemented storage backend

Verified API reference: https://github.com/citizenfx/screenshot-basic#server

Trusted **server exports** `capturePhotoToStorage(player, metadata, callback)` and `readPhotoRecord(id, callback)` are implemented in storage.js. They have no network entry points. Caller metadata must come from server-owned identity; the future inventory orchestrator must validate ownership/session/film before calling. This backend is not itself permission or inventory authorization.

The capture export uses screenshot-basic's server `requestClientScreenshot` API. It writes a JPEG under this resource's `data/photos/` directory using screenshot-basic's HTTP upload, not gameplay events. Records use server-generated cryptographic UUIDs, server timestamps and per-photo JSON files with exclusive publication. Public records exclude the private owner ID. Image data is never inventory metadata. The default maximum is 4 MiB and JPEG boundary bytes are checked; this is not a full decoder/content moderation service. Duplicate finalization never overwrites a record. Failed/time-out captures do not issue items. A late callback cleans unfinished files; already finalized records are retained. A crash during capture may leave orphan files requiring offline maintenance; there is no automatic retention purge.

Optional self-hosted storage uses the existing FiveM resource HTTP route `/d-photomode/photos/<uuid>.jpg`. It serves finalized JPEGs only, never JSON or a directory listing. To use it later, provide permanent HTTPS routing to that endpoint and set the **server** convar:

```cfg
set d_photomode_public_base_url "https://YOUR_REAL_HOST/d-photomode/photos/"
```

The example host is illustrative, not a working provider. Do not use a signed/temporary URL or embed credentials. Empty/unconfigured base URL disables capture and serving. FiveManage has been identified as the intended provider but its API has not been wired or contacted. You may use an existing durable host instead once its supported upload/verification API is supplied.

Back up `d-photomode/data/photos/`, keep it on persistent disk across resource upgrades, and do not replace it with the code checkout. Set a disk quota, monitor disk space and rate-limit/cache the public JPEG route at the HTTPS proxy. Backups must include images and their matching JSON. There is no database migration because storage uses per-photo records. Cross-system inventory transaction durability still depends on the pending QS integration.

The cloud tests exercise local file durability and metadata behavior using test fixtures. **No real FiveM screenshot, deployed HTTP route, upload, inventory transfer, printing flow or public link has been verified.** Existing hosting access and a staging server are required for those checks.

## Implemented viewer

Off-white Polaroid presentation, bounded plain-text caption/name/date, HTTPS image validation, link-copy button, explicit public-link notice and selectable fallback on clipboard failure. There is no Copy Image button: reliable pixel-clipboard support in the deployed NUI has not been demonstrated. Images are released on close. A server-only display event is ready for the ownership-checking item handler; no public client request to view arbitrary record IDs exists. Server-provided photo records must have `id`, `url`, `photographer`, `takenAt`, optional `caption` and `public` boolean. The viewer does not establish inventory ownership by itself.

Development checks:

```sh
PYTHONPATH=/workspace/.photomode-tools python3 -m unittest discover -s tests -p 'test_client.py'
PYTHONPATH=/workspace/.photomode-tools python3 -m unittest discover -s tests -p 'test_sessions.py'
python3 tests/test_ui.py
python3 tests/test_photo_viewer.py
node --test tests/test_storage.cjs
node --check d-photomode/storage.js
node --check d-photomode/html/photo.js
```

Performance/resmon: not measured. In-game prop placement, renderer/HUD capture behavior, FINI compatibility of new capture/prop behavior and QS metadata persistence remain pending.
