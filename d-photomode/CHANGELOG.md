# Changelog

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
