# Changelog

## 0.3.0
- Camera-item entry with native prop/animation and server possession checks. Commands enforce the same item gate; public item use is the default, with optional ACE/job restrictions.
- Actual screenshot-basic capture, overlay-ready acknowledgement and server-only FiveManage V3 upload with retention exemption and permanent URL validation.
- Unique transferable photo items, authoritative server records, plain-text Polaroid viewer, link copying/fallback, and optional film charged only after successful upload.
- Guarded delivery/refund journals, exact-metadata refund attempts, console recovery for confirmed pending refunds, and replay/concurrency controls.
- Preserved FOV/orbit/filter controls; added shutter/flash/printing feedback and original item artwork. New prop/capture/host/SQL persistence behavior requires staging QA; no measured performance or FINI guarantee is claimed.

## 0.2.2
- Preserve gameplay FOV on entry and reset instead of forcing an immediate zoom to 50 degrees; keep focus distance independent of zoom.
- Add 13 native filter choices with adjustable intensity and optional DoF blur strength.
- Add thirds/golden/center guides and letterbox ratios, grouped into Camera/Look/Frame tabs.
- Engine modifier names were checked against GTA data; live visual appearance still requires staging QA.

## 0.2.1
- Use resource-local GTA notifications instead of customized QB-Core notification handlers that may require an uninitialized ox_lib global.
- Report specific ACE, character, job, vehicle and downed/dead-state denial reasons without changing access rules.

## 0.2.0
- Added optional player-centered orbit with front/left/back/right presets and angle, distance and height controls.
- Server grants camera anchor, heading and bounds. Client clamps controls and shortens offsets at obstructions, with active-only collision rechecks.
- Orbit remains disabled by default pending dedicated FINI-enabled staging QA.
- Anchored mode and existing visual controls remain available.

## 0.1.0
- Initial anchored photography staging release.
