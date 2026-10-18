Update my existing FiveM camera mode script into an immersive **Polaroid camera system** for We The People RP, developed by **Dinsoh Development**.

Inspect the existing resource before making changes. This is an update, not a rewrite. Preserve the current camera controls and features wherever they fit the new system.

## Core experience

Players use a camera inventory item to physically pull out a camera, enter camera mode, and take a photograph. After a successful capture, the camera prints a Polaroid, and the player receives an inventory item containing that specific photograph.

The photograph must remain a usable, transferable inventory item. Players should be able to collect photos, put them in supported storage, give them to other players, and open them later.

## Framework and integrations

- QB-Core.
- QS-Inventory, using its actual supported metadata and usable-item functionality.
- ox_lib where appropriate.
- Current FiveM Lua runtime conventions.
- Inspect installed dependencies and existing integrations before choosing APIs. Never invent exports or assume metadata works like another inventory.
- Keep configuration and integration code clear and maintainable.

## Camera item and photography

- Add a configurable usable camera item, such as `polaroid_camera`.
- Using it equips an appropriate camera prop with a convincing animation and correct placement.
- Preserve or improve the existing camera mode, including aiming, zoom, rotation, and framing where supported.
- Show a small, professional control hint while using the camera.
- Hide the camera interface and any resource-owned overlays before capturing the image.
- Provide a shutter sound, brief flash effect where appropriate, and a short printing animation or effect.
- Avoid elaborate visual effects that add unnecessary overhead.
- Prevent overlapping captures, repeated item use, and print spam.
- Clean up props, cameras, UI focus, and player state when exiting, dying, losing the item, or stopping the resource.

Include optional film consumption in configuration. If enabled, each successful printed photograph costs one unit of film. Keep the item names and film requirement configurable.

## Real image capture and storage

Capture an actual image of the player’s framed game view. Do not use placeholder photos.

Inspect the existing capture implementation and use a supported screenshot/upload dependency where needed. Explain any limitations affecting framing or HUD visibility.

Images need durable storage so the resulting photos continue working after reconnects and server restarts.

- Inspect the current image hosting setup before adding another service.
- Use a supported upload flow with reasonable image quality and file size.
- Never expose private upload credentials, webhook URLs, or storage secrets in client scripts or NUI.
- Do not use temporary image URLs that will expire and break saved photographs.
- Keep image bytes out of inventory metadata and avoid sending screenshots through ordinary server events.
- Validate upload completion before issuing the finished photo item.
- Handle failed captures, failed uploads, unavailable storage, and full inventories without silently losing film or creating duplicate photos.
- If hosting requires external setup, document it honestly instead of claiming it works without configuration.

## Individual Polaroid inventory items

Each successful print creates a separate photo item, such as `polaroid_photo`.

Every photo must retain its own identity and metadata. Different photographs must never merge and overwrite one another.

Store appropriate metadata, including:

- Unique photo ID.
- Persistent image URL or storage reference.
- Date and time taken.
- Photographer’s roleplay name.
- Optional short caption, if enabled.

Use a server-side photo record as the authoritative source, with only the necessary display data stored in inventory metadata. Avoid exposing private player identifiers in the photo interface.

Ensure the photo’s metadata survives supported inventory transfers, storage, reconnects, and restarts. Verify how the installed QS-Inventory version handles this.

## Viewing photographs

Using a photo item opens a polished Polaroid viewer showing that item’s photograph.

Design direction:

- Minimal, professional, and immersive.
- Off-white Polaroid border with a slightly larger bottom margin.
- Photograph as the main focus.
- Small caption and date details.
- Subtle transitions.
- Simple close and copy controls.
- Responsive sizing for different screen resolutions.
- No oversized dashboard, unnecessary menus, or excessive branding.

Players must be able to close the viewer with Escape. Opening or closing it must reliably restore NUI focus and controls.

## Copying and using images elsewhere

Add a **Copy Image Link** button so players can copy the photograph’s direct image URL and paste it into Discord, a browser, or elsewhere.

Copying the link must not remove or consume the photo item.

If copying the actual image pixels to the clipboard is supported reliably by FiveM’s NUI environment, add it as a separate **Copy Image** option. Check support first. Do not label URL copying as image copying.

Provide clear success or failure feedback. Include a selectable URL fallback if clipboard access is unavailable.

Only expose a public image URL when the configured storage supports it. Explain that a copied public link can be viewed by anyone who has it.

## Security and reliability

The server must validate that the player owns the camera and meets any configured film requirement before authorizing a capture.

- Use a server-authorized capture session with a short-lived identifier.
- Permit only one active capture per player.
- Validate the completed upload against that session.
- Prevent replaying requests to generate extra photos.
- Validate image URLs or storage references against the configured provider.
- Do not accept arbitrary client metadata as authoritative.
- Validate photo ownership when a player requests to open an inventory photo.
- Render captions as plain text and limit their length.
- Keep secrets server-side.
- Apply sensible cooldowns and request limits.

Handle cancellation and failure cleanly, including disconnects during capture and inventory changes before printing.

## Optimization

This resource needs to suit a heavily populated server with approximately 320 players.

- No continuous inventory polling or server-wide photo broadcasts.
- No per-frame loops when the camera is inactive.
- Keep necessary per-frame camera controls limited to the active camera session.
- Load images when viewing them and release unnecessary resources afterward.
- Keep image transfers out of gameplay networking.
- Avoid unnecessary dependencies and repeated database queries.

Do not claim performance figures without measuring them.

## Delivery

Deliver complete updated resource files, not isolated snippets.

Include:

- Updated scripts and NUI.
- Configurable item names, film requirement, cooldowns, and storage settings.
- Correct QS-Inventory item definitions.
- Any required database migration, following the resource’s existing migration approach.
- Item images if the resource does not already have suitable ones.
- A README with installation, dependencies, hosting configuration, and usage.
- A clear explanation of what was changed and what still needs in-game verification.

Verify the complete flow:

**Use camera → frame photograph → capture and upload → print Polaroid → receive photo item → open photo → copy link → transfer photo → reopen after restart.**

Also check cancellation, upload failure, full inventory, duplicate requests, and cleanup.

Keep the implementation appropriate to the existing resource. Avoid unrelated features or unnecessary rewrites.

Owner clarification: camera must be a QS-Inventory item; existing hosting is FiveManage. Preserve tested controls, correct initial FOV, and provide native filter customization. Installed QS APIs and FiveManage upload integration remain to be inspected from supplied files/docs.
