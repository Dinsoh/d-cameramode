# Dinsoh Development × We The People RP — Master Codex Instructions

> **Purpose:** Durable working context for Codex across FiveM projects. Read before planning, editing, reviewing, or packaging resources. These instructions are a **preference and engineering handbook**, not evidence that a specific API, dependency, feature, or file exists. **Inspect the current repository and ask when a consequential assumption cannot be verified.**
>
> **Priority:** User's current request > verified repository behavior and security constraints > project-specific requirements > this handbook's defaults. Preserve deliberate project exceptions. Update this file only when the owner confirms a lasting change.

## 1. Identity, brands, and deliverables

- **Dinsoh Development** is the owner's developer brand for original FiveM scripts, tools, design assets, and commercial/public Tebex releases. Use this brand in author credits, storefront-ready documentation, and general-purpose products where appropriate.
- **We The People RP (WTPRP)** is the live FiveM RP city and a production integration environment. It is not synonymous with Dinsoh Development. WTPRP-only content can carry WTPRP branding; reusable products should be brand-neutral or Dinsoh Development branded unless explicitly requested.
- **Bunker Motors** is a specialized in-city underground mechanic business associated with the owner's custom creations. It is primarily operated by the owner and his girlfriend; do not assume a large employee hierarchy or invent employee-management bureaucracy.
- Match the **existing resource's** names, commands, colors, wording, logos, prefixes, and file structure. Do not rename everything for consistency. Some resources use `d-` names; this is a precedent, not a mandate.
- For public/Tebex releases, produce clean distribution artifacts: working resource, concise README, install guide, configuration and dependency notes, changelog if useful, example items/images/SQL only when actually required. Exclude `.git`, test fixtures, development junk, credentials, logs, unnecessary source maps, and private data. **Do not remove source files or licenses that the release requires.**
- Never silently introduce license locks, analytics/telemetry, obfuscation, remote checks, webhooks, branding splash screens, monetization mechanics, or external services.

## 2. Core product philosophy

1. **Production reliability and exploit resistance** before flashy features.
2. **Low client and server cost** at 300–320 concurrent players; idle work should be negligible.
3. **Immersion and natural gameplay** instead of arbitrary cooldowns, grind, or artificial gates.
4. **Professional, restrained UI** that fits the resource and does not feel templated or machine-generated.
5. **Minimal implementation surface:** no duplicate code paths, speculative systems, excessive defensive wrappers, unnecessary dependencies, or sprawling configuration.
6. **Preserve what already works.** Requests described as updates are not permission to rewrite entire resources.
7. **Complete, ready-to-use output:** no TODOs, fake integrations, stub handlers, or unsupported promises.

The owner regularly rejects “AI slop”: generic panels, unnecessary cards, filler copy, gratuitous animations, endless notifications, complex subsystems without gameplay value, and code written merely to look comprehensive. **Every feature and abstraction must justify its cost.**

## 3. Known FiveM ecosystem — verify per repository

- Core: **QB-Core**.
- Inventory: **QS-Inventory** (Quasar); verify current exports and metadata behavior. Other projects may use qb-inventory or ox_inventory; do not mix APIs.
- UI / utilities: **ox_lib**, with **Lua 5.4** when compatible and requested. Prefer ox_lib for existing callback, menu, notification, input, and progress workflows when it reduces custom code; do not replace an established bespoke UI merely because ox_lib exists.
- Interaction: **qb-target** in many resources; confirm target API and actual dependency.
- Persistence: SQL / **oxmysql** where appropriate; confirm schema, migrations, and actual database library.
- Vehicles/shops: **jg-mechanic**, **jg-advancedgarages**, and related customization systems. Prior integration with **lambra tuning chip v2** and custom **d-engswap** may matter for handling/performance scripts.
- EMS: **osp_ambulance** in newer WTPRP work; older projects used wasabi_ambulance. Verify current use.
- Weather: **Renewed Weather Sync**, custom storm/flood resources, and possibly client graphics mods such as QuantV. Do not assume universal water or visual behavior.
- Anticheat: **FINI / FiniAC**. A prior banking resource included FINI event integration, but that does **not** automatically authorize new scripted cameras or exempt them from detection.
- Other resources vary by project: ps-dispatch, illenium-appearance, custom police/DOJ systems, business and housing resources. Never assume an export name or version from memory alone.

**Integration protocol:** Read `fxmanifest.lua`, configuration, server/client entry points, current exports/events, and dependency docs or actual source. Confirm load order, server build, and resource version. Use a thin adapter only where necessary. Do not hardcode exports or inject SQL blindly.

## 4. UI/UX design language — strong recurring preferences

### Visual direction

- **Clean, modern, polished, purposeful, restrained**. Interfaces should look authored by a professional developer, not generated from a generic admin-dashboard template.
- Favor **minimal composition, strong alignment, thoughtful spacing, consistent typography, clear visual hierarchy, subtle contrast**, and coherent states.
- Use **few colors**, applied intentionally. Prefer matching the existing resource's palette. A **minimal light-blue** look was specifically requested for the plate-hider UI at one stage; it is **not** a universal color requirement. WTPRP branding was used on another version; do not assume it belongs in every product.
- Avoid clutter: unnecessary borders, nested cards, thick outlines, gradients, oversized shadows, neon everywhere, decorative icons, excessive rounded boxes, giant headers, fake telemetry, and filler explanatory text.
- Prefer **compact, readable controls** that fit GTA gameplay and don't cover critical screen space. Use responsive sizing across common aspect ratios/resolutions; avoid clipped menus and awkward scaling.
- Maintain consistent hover, selected, loading, disabled, success, error, and empty states. UI should feel smooth without heavy transitions.
- Use actual asset quality: properly sized/transparent item images where appropriate, consistent visual assets, and crisp readable labels. Don't invent unrelated images or placeholders.

### Interaction and feel

- **Reuse existing NUI and minigames** before building another UI framework.
- Contextual UI only: show controls, diagnostics, maintenance details, or prompts **when relevant**. No always-on condition meters unless explicitly asked.
- Notifications should be **rare, short, useful**, and in-world where possible. Prefer physical/audio feedback and contextual interaction over alert spam.
- Interactions should happen at **credible vehicle locations** (trunk, engine bay, wheels, fitting station) with appropriate positioning and animations when gameplay calls for it. Don't force long animations for trivial actions.
- Controls must be intuitive and documented; respect project-specific controls (e.g., an existing plate-fitting camera rotation workflow). Never globally impose a control scheme based on one minigame.
- Support clean cancellation, focus restoration, NUI escape behavior, resource stop, death, disconnect, and interaction interruption.
- Minigames should add meaningful tension, not become arbitrary chores. Scale difficulty with context and avoid repetitive progress bars when an existing interaction already communicates progress.
- The owner's preferred standard is **immersive without being frustrating**: subtle mechanical behavior, polished motion, believable consequences, and player agency.

### NUI engineering

- Use existing frontend framework or vanilla HTML/CSS/JS as appropriate; don't add React/Vue/build pipelines for a simple UI.
- Avoid permanent DOM animation and unnecessary rendering while hidden. NUI should receive only relevant updates, sanitize displayed content, and never decide economic or privileged outcomes.
- Use focus only while needed; always release focus on close/error/resource stop. Guard duplicate messages and repeated submits.
- Keep web assets local and packaged correctly. Do not introduce external CDN dependencies without approval.

## 5. Code style and architecture

- **Inspect before editing.** Map current flow and identify the smallest integration points; explain material tradeoffs before large changes.
- Follow existing Lua/JS naming and layout unless there is a clear bug. Prefer descriptive names and small cohesive functions; avoid clever abstractions and giant catch-all managers.
- Separate client presentation/vehicle natives from server authority and persistence. Keep shared config narrow and organized. Never put secrets in shared/client files.
- Prefer **events/callbacks and state transitions** over polling. Use a loop only when an active mechanic genuinely requires per-frame behavior; start it on entry and stop it immediately on exit.
- Don't create new timers for things derivable from timestamps (e.g., cooling/stress decay). Don't scan every player/vehicle every tick. Cache carefully, invalidate on changes, and avoid stale entity handles.
- Prevent duplicate registrations, concurrent interactions, race conditions, stale callbacks, double rewards, and overlapping state transitions. Validate identifiers and handle entity deletion/net ID reuse.
- Use the **smallest sufficient persistence model**. Avoid one DB query per animation frame or activation. Batch/debounce writes safely, but protect critical transitions from loss on crash/restart. Document the actual durability guarantees.
- Use **idempotent** installation/migration routines where possible. Never assume an SQL file can be executed automatically by every environment; verify permissions and offer a safe manual fallback.
- Keep configurable balancing (wear rates, thresholds, costs, timing, allowed jobs) in one obvious location. Avoid huge config files with dozens of speculative toggles.
- Debug mode off by default; no console spam, warnings for expected gameplay, or leaking identifiers/secrets in logs.
- Do not add tests solely as packaging clutter, but do include useful automated or reproducible tests in the **development** repository when they protect logic; keep release bundles lean.
- If code needs a new dependency, explain why the existing stack cannot do the job.

## 6. Performance standards

- **Target near-zero idle client resmon** where practical, often displayed as `0.00 ms`, but never promise a literal universal zero or misrepresent benchmarks.
- Consider both client and server cost at **300–320 concurrent players**, including worst-case simultaneous activations and large vehicle/resource packs.
- No idle `Wait(0)` loops, global per-tick vehicle sweeps, repeated native calls, gratuitous state bag writes, per-frame SQL, broad event broadcasts, or UI refreshes with unchanged data.
- Use proximity checks only if justified, at adaptive intervals, and only when relevant; prefer qb-target/interaction events already available.
- Client-local cosmetics should remain local unless other players must observe them. Network only authoritative state and necessary visual synchronization.
- Measure **idle, normal active, and stress/concurrent** usage. Report actual profiler/resmon evidence and hardware/server context, or explicitly say not measured.
- Optimization must not compromise correctness, authoritative checks, or persistence. A claimed `0.00 ms` resource with exploits is unacceptable.

## 7. Security and anti-abuse rules

- **Server is authoritative** for money, rewards, inventory consumption, purchases, repair outcomes, degradation, permissions, and persistent vehicle state.
- Treat all client events and NUI callbacks as untrusted. Validate player, proximity, item possession, job/role, target vehicle, current state, rate, quantity, and allowed transitions on the server.
- Use server-side locks/idempotency where necessary for simultaneous purchases, repairs, claims, item use, or repeated callbacks. Ensure failure paths release locks and don't duplicate/lose items.
- Check all access control at execution time, not only when the UI opens. Avoid trusting client job labels or user-submitted price/quantity/condition.
- Anti-spam should feel **natural** in gameplay when possible: mechanical wear, limited real stock, economic costs, legitimate seizure, and finite part lifespan instead of arbitrary daily quotas.
- For FINI, **do not disable, spoof, hide from, bypass, or claim whitelisting is unnecessary without evidence**. Design supported, constrained features and test with the actual anticheat enabled. Where official compatibility is needed, say so.
- Never describe a resource as “100% exploit-proof” or “FINI-proof.” Specify tested threats, remaining risks, and rollout requirements.
- Never embed private tokens, credentials, webhook secrets, or Tebex secrets in deliverables.

## 8. Gameplay design principles

- Systems should create **real RP opportunities** and reasons for businesses/emergency services to matter, rather than giving everyone instant self-service replacements.
- Avoid enabling item hoarding, endlessly reusable advantages, unlimited stock, effortless duplication, and repeated reward farming.
- Prefer meaningful failure, wear, upkeep, scarcity, role-based services, and consequences that follow from player actions. Balance to avoid punishing normal use.
- Preserve distinctions between legal and illegal business loops; do not turn every feature into a police chase or minigame.
- When player-owned businesses are involved, think about **owner accountability** as distinct from employee activity. An active employee base doesn't necessarily mean the owner is meeting responsibilities.
- New features should make sense in a heavily populated RP city; account for economy, availability when specialist players are offline, and abuse by coordinated groups.

## 9. Project precedents and explicit exclusions

### Plate hider — Bunker Motors

- An existing custom script has fitting (`/platefit`), installation/removal, animations, plate designs, concealment behavior, and persistence. **Updates must preserve those unless specifically changed.**
- Preferred maintenance model: **100% condition initially; wear on opening/closing**, not passive driving; approximately **50–80 normal activations** as an initial balance target.
- Gradual faults: hesitation, slower movement/grinding, higher jam risk at low condition; device eventually fails. **Server-authoritative** wear and malfunction results.
- **Basic player maintenance** via specialized kit, small recovery; **motor replacement and full rebuild** at Bunker Motors; structural maximum decreases with rebuilds, finite rebuild lifespan.
- Rapid toggle **motor stress** and lazy timestamp-based cooling; normal usage shouldn't be punished.
- Minimal, contextual diagnostics and QS-Inventory integration/metadata where appropriate; avoid forced non-stackable item behavior unless technically required and approved.
- **Explicitly excluded:** serial numbers/device history/tracking system; emergency manual-release feature. Keep existing standard removal, not a new recovery minigame.
- Do not add arbitrary account-wide purchase cooldowns or extensive employee auditing by default.

### Scratch-offs — Dinsoh Development

- Existing custom scratch-off resource with a distinct UI and QB-Core money flows. User requested **Lua 5.4 + ox_lib** integration while preserving gameplay/UI and QS-Inventory compatibility.
- Critical concerns: atomic rewards, no duplicate redemption, concurrency locks, correct inventory handling, clean errors, and Tebex-ready packaging. Keep dev tests out of consumer zip unless needed.

### Mechanic system — ambitious future/ongoing design

- Vision: deeper **jg-style** mechanic gameplay, more meaningful parts and handling effects, realistic wear/failure, servicing and calibration, diagnostics/data logger tablet or laptop, physical component interaction/props, custom minigames, and genuine need for towing when vehicles break down.
- Prevent repair-kit abuse by both players and shops. Consider integrating/replacing an existing custom vehicle-failure script rather than layering duplicate failure engines.
- This is **project-specific ambition**, not permission to add a full vehicle simulation to unrelated resources.

### Vehicle handling and tuning

- User favors **planted, predictable grip**, smooth acceleration/gearing, effective braking, controllable steering, believable suspension; retain drivetrain character and intentionally configured drift setups.
- Trucks/SUVs should feel heavy but not constantly roll over. Vehicle classes have different stock top-speed targets; don't blindly normalize every car.
- Vehicle metadata and handling must remain compatible with installed mechanic/tuning/engine-swap systems. Identify duplicate handling entries and validate streamed metas; don't invent physical assets.

### Weather / flooding

- Staff-triggered emergency storm using Renewed Weather Sync, severe rain/wind, server alerts, occasional outages, and flood behavior. Police can close/divert roads during incidents.
- Previous flood testing exposed **water surface flicker/disappearance**, cutoffs, swimming problems at extreme heights, and QuantV interactions. Favor stable, smoothly rising water and engine-supported limits over impossible visual promises.
- Map/prop optimization is important for low-end PCs and high concurrency.

### Halloween / collectibles

- Single cohesive Halloween resource rather than several overlapping scripts. Spooky but professional aesthetic; rare collectibles, collectible-card-like items, possible vehicle prize, integration with existing inventory/garages/EMS.
- Avoid corny/generated-looking assets, common farmable spawns, and excessive client scanning. Keep debug visibility available for testing, off in production.

### Business accountability

- Consider tangible business licenses and recurring contract fulfillment, with consequences for sustained nonperformance; explicitly distinguish **owner involvement** from employees keeping a shop operational. Integration with existing boss menus/business resources is preferable to replacing them.

### Furniture thumbnail tooling

- Maintain precise asset naming, mapping, transparent thumbnails, deduplication, and usable GitHub packaging. Avoid deleting referenced images or claiming missing thumbnails are present without matching files.

### Camera / photography mode

- Goal: polished RP photography, filters, DoF, FOV, zoom, exposure, composition guides, subtle camera motion, optional posing.
- **FINI is a major constraint.** Do not attempt anticheat evasion or claim unrestricted freecam is safe. Prefer anchored/stationary camera modes, explicit session authorization, constrained movement, and safe cleanup; test with FINI enabled before enabling anticheat-sensitive options.
- Reference banking resource (`wtp-banking.zip`) has camera code and FINI integration files. **Reference only; not a guaranteed API contract or a dependency.** See the camera-specific prompt for the current scope.

### Other recurring integrations

- Housing/garage persistence, police/DOJ tools, vehicle audio/lighting, loading screens, Discord bot/Tebex workflow, and event scripts may matter when explicitly in scope. Do not import these systems into every project merely because they exist elsewhere in WTPRP.

## 10. Discord, Tebex, documentation, and branding

- Dinsoh Development aims for a **sleek, professional** Tebex presence and Discord support workflow. Copy should be confident, clear, and concise; avoid generic hype and filler.
- Discord bot precedent: **Node.js / discord.js**, modular commands, `.env` token storage, role-based authorization, minimal embeds, persistent ticket interactions, and robust permission diagnostics. Existing ticket panel supports multiple ticket types; don't rebuild it without a reason.
- Packaging should be **copy/paste and install-ready** with precise paths, load order, item registration, SQL/migration steps, and required dependencies. Explain optional versus mandatory files.
- README should include: overview, requirements, installation, configuration, commands/items/exports if present, known limitations, troubleshooting, and version notes when relevant.
- Never say something was installed, tested, deployed, or validated unless that action actually happened.

## 11. How Codex should work on every request

1. **Read this file**, project-specific instructions, and the user's latest request.
2. **Inventory the actual repository**: manifests, configs, dependencies, events, exports, NUI, SQL, assets, and existing tests. Don't rely on old summaries as source truth.
3. **State a minimal implementation plan** when the task is substantial; identify what will remain unchanged.
4. **Implement narrowly**, preserving compatible APIs, persistence, item behavior, animations, and existing UI.
5. **Review exploit paths**: repeated events, stale state, concurrency, forged client values, missing items, permission changes, resource restart, disconnect, and rollback.
6. **Test** syntax/build, functionality, negative cases, persistence, and relevant integrations. Distinguish automated tests from in-game tests requiring the user's server.
7. **Measure** performance where tools permit; do not invent resmon/server timings.
8. **Deliver** the complete resource/patch and short change summary, setup/migration instructions, testing results, and unresolved dependencies or limitations.

### Response style to owner

- Be direct, technically precise, and pragmatic. Avoid self-congratulatory language, vague “enterprise-grade” claims, and endless option lists.
- Explain **what changed, why, how to install, what was verified, and what still needs in-game testing**.
- When the owner says “just fix it,” prioritize an actual patch over lengthy theoretical advice, but never fabricate success.
- When brainstorming, propose creative mechanics that have a concrete RP payoff and realistic implementation cost; clearly separate suggestions from approved scope.
- Ask questions only when an unanswered detail materially blocks safe implementation; otherwise use existing conventions and document reasonable defaults.

## 12. Memory hygiene and maintenance

- This file is a **living instruction document**, not automatic access to past chats. Codex should not claim to remember conversations it cannot see.
- When a preference is confirmed across projects, update this master file. Put one-off design choices in the relevant repository's project-specific instructions or README.
- Distinguish **confirmed user preference**, **observed codebase fact**, **historical precedent**, and **proposed default**. Never turn a historical tool version or one-off UI choice into a global mandate.
- For a multi-repository setup, keep this handbook accessible at the workspace root or copy/synchronize it into each repository's applicable `AGENTS.md` location. Project-specific `AGENTS.md` files can add narrower rules.
- When this handbook conflicts with the current repo's tested behavior, investigate and explain rather than force a breaking change.
