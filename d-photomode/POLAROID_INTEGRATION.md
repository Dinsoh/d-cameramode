# Integration evidence and durability

## QS source inspected

The privately supplied `inv.zip` was inspected locally and is not included in Git or the release. No attempt was made to decrypt escrowed files. Its manifest/version was not supplied, so compatibility is scoped to the readable customization source, not an invented QS version claim.

- `server/custom/misc/AddItem.lua`: `AddItem(source, item, amount, slot, info, data, created, lastinventory, disableAutoShowBox)` is exported. It enforces configured slots/weight, stores `info` and updates the framework before successful return. Some failure branches return a notification result; this integration verifies snapshot outcomes instead of treating any truthy return as success.
- `server/custom/misc/RemoveItem.lua`: exported `RemoveItem(source, item, amount, slot, metadata, disableAutoShowBox)`. This integration validates the exact film slot/name before calling and checks the resulting quantity.
- `server/custom/framework/qb.lua`: reads `QBCore.Shared.Items` and synchronizes `player.PlayerData.items` using `SetPlayerData('items', items)`.
- `shared/inventory.lua`: `unique` and `stack` control stacking; metadata comparisons use `item.info`.
- `server/inventory/slots.lua`: clone/swap operations preserve the `info` table. Supported QS storage/save paths keep those items. Full live SQL save/reconnect behavior still requires QA.
- `server/custom/misc/UseItem.lua`: emits the trusted local `inventory:usedItem` event and accepts callback `.func`/`.cb`/`.callback` shapes. QB-Core's conventional `CreateUseableItem` registration and that verified QS event feed one deduplicated item dispatcher. No undocumented inventory exports are guessed.

Optional `tests/test_qs_reference.py` executes the supplied readable add/remove/stack code with framework doubles when `QS_REFERENCE_DIR` is provided. It does not bundle vendor code or replace live integration testing.

## FiveManage sources

Official documentation source: [fivemanage/mintlify-docs](https://github.com/fivemanage/mintlify-docs), inspected revision `e441647fe95980c2536799d8f65ea006339e4729`. Relevant files: `openapi.json`, `guides/uploading-files/images.mdx`, `api-reference/migrate-from-v2.mdx`, `guides/integration/lb-phone.mdx`.

The official SDK was inspected as an additional reference ([fivemanage/sdk](https://github.com/fivemanage/sdk), revision `013032014577f8750376fbf09354544f2a8a74d1`); it is not a runtime dependency and no SDK log/telemetry features were imported.

The implementation uses `POST https://api.fivemanage.com/api/v3/file`, multipart field `file`, private server Authorization header, server UUID filename, and `retentionExempt=true`. Success requires HTTP 2xx, `status=ok`, a file ID and a canonical permanent HTTPS `r2.fivemanage.com` image URL; `originalUrl` supports accounts with a custom CDN. Redirects, expiring query URLs, arbitrary hosts, credentials in URLs and oversized/malformed responses are rejected. Errors are sanitized. No key from chat was saved, committed or used in a live request.

The official LB Phone guide identifies its provider settings in `lb-phone/config/config.lua` and private keys in `lb-phone/server/apiKeys.lua`. This resource does not read those files. Configure a rotated key via a private convar, optionally reusing an existing private `FIVEMANAGE_MEDIA_API_KEY` binding. Never replicate it with `setr` or publish it with `sets`.

## Capture and delivery protocol

1. QB/QS item use and command aliases all require server-observed camera possession, eligible character state and configured permission rules.
2. Each short-lived session belongs to one source/character and server-observed ped anchor. Each capture has one short-lived ID and a checked phase.
3. Camera changes are flushed before capture. NUI/cursor/owned overlays are hidden; two frames later a matching ready acknowledgement authorizes one screenshot.
4. screenshot-basic's supported server API transfers the game image over its HTTP handler. Its server callback returns a JPEG data URI; only server resources exchange those bytes, never ordinary gameplay net events. The resource writes inside its own `data/photos/` directory, avoiding cross-resource filesystem writes.
5. Size/encoding are checked, and the server uploads directly to FiveManage with its private key. An incomplete upload does not mint an item or consume film.
6. An immutable server record is committed before printing. A single-use delivery journal is prepared before changing inventory. At delivery, character/session/position/camera/film are revalidated. One film is removed and one unique photo is added without an intentional wait between those QS operations. Failed addition attempts an exact-metadata film refund.
7. Delivery/refund outcomes are journaled. Confirmed refund failures support the console-only recovery command. A stale/duplicate ready event, screenshot callback, upload completion or delivery preparation cannot print the same record again.
8. Photo use reads its current server-side slot, verifies possession again after record lookup, and sends only public display fields to NUI. The original photographer is not the permanent owner: transferred photos work for their new holder. Client-provided URLs/captions are never the viewing authority.

JSON files are exclusive on initial publication, flushed and atomically replaced for journal transitions. Directory sync is used where supported. QS's own database saves and these files are separate systems: a crash during mutation/save can be ambiguous. Such journals are quarantined from automatic reissue/refund; staff must reconcile the actual inventory state. This implementation does not claim crash-proof distributed inventory transactions.

A cancelled/uncertain upload may leave orphan media, especially if the provider stored it but the response was lost. No automatic media deletion can remove an already printed photograph. Maintain backups and review unissued/orphan records carefully. The optional `local` provider remains an explicit fallback and is off by default; it needs a permanent HTTPS route and `d_photomode_public_base_url`. The FiveManage mode exposes no local image route.

## Verification boundaries

Automated tests execute camera/session logic, real supplied readable QS add/remove/stack functions with doubles, capture/delivery failures, viewer behavior, local file/restart durability, delivery replay protection and mocked FiveManage HTTP responses. Browser tests exercise the actual NUI with mocked FiveM transport. They are not a real FiveM game render, a live FiveManage auth test or deployed QS SQL reload.

In-game capture, prop placement/network cleanup, FINI behavior, actual clipboard permission, QS transfer/storage/restart and measured idle/active/stress performance remain staging checks. See `TEST_PLAN.md`.
