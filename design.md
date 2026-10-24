# Design Specification — Coin Atelier
**Document type:** Game design & visual design specification  
**Working title:** Coin Atelier (placeholder; perform trademark/store-name checks before release)  
**Target:** Android first; iOS-ready Flutter codebase  
**Engine:** Flutter + Flame, with Flutter UI overlays  
**Status:** Production blueprint — implementation must validate all mechanics with playable prototypes

> Product principle: build an original coin-sorting/merging puzzle inspired by the genre, not a clone of Pocket Sort. Do not reuse its name, art, UI layout, levels, copy, sounds, or other protected assets. Create a distinctive visual identity and original puzzle content.

## 1. Product vision

Create a premium-feeling, approachable, tactile coin-sort puzzle with satisfying merges, thoughtful strategy, transparent rules, fair solvability, short sessions, and respectful monetization. It should feel polished from the first 30 seconds and remain interesting through hundreds of authored and generated levels.

### Product pillars
1. **Fair by construction:** every standard level has a verified solution before it ships or is offered.
2. **Tactile satisfaction:** coin pickup, stacking, landing, matching, merging, and clearing all have distinct animation and audio feedback.
3. **Readable at a glance:** color is never the only indicator; use symbols, edge patterns, labels, and high contrast.
4. **Relaxed but strategic:** no forced timer in core campaign; optional challenge modes may have timers.
5. **Honest economy:** no hidden difficulty manipulation, no misleading “no moves” states, no ad interruptions during a puzzle.
6. **Original premium presentation:** warm workshop / collector’s cabinet theme, glossy enamel coins, soft shadows, restrained highlights, tasteful depth.

## 2. Positioning and target audience

- Casual puzzle players seeking 2–8 minute sessions.
- Players who enjoy sorting, matching, collection, and visible progression.
- Players who prefer a calm experience without time pressure.
- Accessibility-minded players who benefit from readable labels and optional reduced motion.

**Core promise:** “Sort thoughtfully. Merge beautifully. Every move makes sense.”

## 3. Core game loop

1. Open the app and see the current chapter, streak/reward, and Continue button.
2. Start or resume a level.
3. Inspect coin stacks, tray/slots, special coins, and objective.
4. Tap a source stack, then tap a legal destination; dragging may be supported as an optional input.
5. Move the top movable coin or a defined contiguous group according to the active level rule.
6. When a matching group reaches the merge threshold, play a merge animation and resolve the board state.
7. Complete the objective, receive a concise win moment, rewards, and next-level action.
8. If no legal move exists, show an accurate explanation and fair choices: undo, use an earned booster, restart, or exit. Never falsely claim the puzzle is stuck.

## 4. Visual direction

### Theme: The Collector’s Atelier
A modern tabletop coin workshop with a deep midnight-teal backdrop, warm ivory panels, brass/gold accents, and luminous enamel coins. The board is the hero; UI should frame it rather than compete with it.

### Color tokens (initial proposals; validate contrast)
- Background: deep teal `#102A2A`
- Surface: warm ivory `#FFF5E5`
- Primary: jade `#21B7A5`
- Accent: brass `#E8B85A`
- Text primary on light: `#172626`
- Text primary on dark: `#FFF8EA`
- Danger: `#C94D55`
- Success: `#2C9A68`
- Disabled: neutral gray with a clear disabled treatment

Do not communicate coin identity through hue alone. Each coin family should have a distinctive center glyph, rim pattern, and optional short label. Include a color-blind mode with stronger symbol/rim differences.

### Coin art
- Coins are round, slightly beveled, with a readable center emblem and layered rim.
- Use hand-authored vector or high-resolution sprite assets with multiple lighting states.
- Fake depth using layered rim highlights, inner shadows, a small contact shadow, and a consistent light source from upper-left.
- Keep the coin silhouette and glyph readable at the smallest supported phone size.
- Special coins must have clear visual states: locked, frozen, linked, hidden/unknown, active, selected, and target-highlighted.
- Avoid excessive bloom, flashing, or screen shake. Provide reduced-motion settings.

### Board and slot design
- The playfield is centered and sized responsively, preserving tappable targets.
- Slot/stack surfaces use a contrasting but quiet material; selected stack gets a thick focus ring and lift.
- Destination legality is indicated before commit. Invalid moves produce a gentle nudge and short accessible message, not a punitive animation.
- Always reserve space for objective, move feedback, booster row, undo/restart, and pause.
- Avoid placing important controls under system gestures or ad safe areas.

### Motion principles
- Input response: immediate (<100 ms perceived response target).
- Pickup: 100–160 ms lift and shadow expansion.
- Move: 160–260 ms ease-in-out arc, with subtle rotation only if it helps depth.
- Merge: 220–420 ms compress, flash, coin-stack settle, particle burst; no full-screen strobe.
- Win: 600–1000 ms celebratory but skippable.
- Motion must not change logical outcomes. Game state changes are committed atomically; animation is a presentation of the already-valid transition.
- Pause, backgrounding, and reduced-motion mode must not corrupt a transition.

### Audio
- Separate toggles for SFX and music; haptics independently configurable.
- Short, layered sounds for select, move, legal placement, merge, objective progress, win, undo, and invalid action.
- No loudness spikes. Avoid audio feedback that implies a move succeeded when it did not.
- Respect device silent mode and OS audio focus expectations.

## 5. Screen inventory and layout intent

### A. Boot / loading
- Branded mark, asset loading indicator only when necessary, recover interrupted session.
- Do not show an ad before the player understands the game.
- Handle offline start and corrupt-save recovery.

### B. Onboarding (first session only)
1. Welcome and one-sentence promise.
2. Interactive tutorial with a tiny deterministic board.
3. Teach source selection, destination selection, matching/merge, undo, and objective.
4. Explain any special coin only when first introduced.
5. Finish with a small reward and “Play next”.
- Let the player skip non-essential text, but do not skip essential interaction teaching.
- Tutorial state is resumable and never blocks the player after app restart.

### C. Home / chapter map
- Continue button is visually dominant.
- Chapter/collection progress, daily reward (if enabled), settings, shop, and events are secondary.
- No deceptive close buttons, fake system dialogs, or forced purchase modal.
- Display current level and earned currency balance clearly.

### D. Gameplay
- Top: back/pause, level/chapter, objective/progress.
- Center: coin board with clear stack depth and legal destination feedback.
- Bottom: booster buttons with counts and clear cost labels, undo, optional hint.
- Persistent accessibility and pause access.
- The board should occupy the largest useful area while keeping controls thumb-reachable.

### E. Pause/settings overlay
- Resume, restart (with confirmation if progress would be lost), sound/music/haptics, vibration, reduced motion, color-blind mode, language, privacy, support.
- State is saved before leaving a level.

### F. Level complete
- Clear success feedback, reward breakdown, optional collection unlock, Next Level.
- Do not insert an interstitial immediately after every win. Use controlled frequency caps and only between levels.

### G. No legal moves / blocked board
- Must only appear after the solver/legal-move checker confirms no valid moves under the actual rules.
- Explain choices without blame: Undo, Use booster, Restart, or Return to map.
- Do not use false scarcity or imply payment is required if a free path exists.
- If a standard level unexpectedly becomes unsolvable, record a diagnostic event and provide a free recovery path.

### H. Shop / economy
- Separate earned soft currency from any premium currency.
- Clearly label free, rewarded, and paid rewards.
- Confirm purchases; restore purchases where applicable.
- Never sell a “solution” to a level intentionally made impossible.

### I. Collection / coin cabinet
- Display discovered coin families, chapter sets, and cosmetic skins.
- Cosmetics do not alter puzzle odds or rules.
- Duplicate rewards should convert transparently to a disclosed amount.

### J. Daily challenge / events (post-launch)
- Fixed, versioned seed and explicit rules.
- Leaderboards only if anti-cheat and privacy design are implemented.
- Event expiry and rewards must be communicated honestly.

## 6. Gameplay rules — canonical version

These rules are a starting specification and must be represented in one engine-independent rules module.

- Board contains stacks/slots, each with a defined capacity and ordered coin contents.
- Each coin has a stable ID, family/type, special-state flags, and optional link/group ID.
- A move is legal only when source is non-empty, source top coin is movable, destination exists, destination has capacity under the selected rule, and special constraints are satisfied.
- Default campaign rule: move one top coin to an empty slot or to a compatible stack. Compatibility and merge threshold must be defined by level rules, never inferred from rendering.
- A merge occurs only when the configured threshold of compatible coins is met. Define whether coins merge on landing or after the player explicitly confirms; use one consistent rule throughout a chapter.
- Any resulting chain reaction is deterministic and resolves in a documented order.
- A move is one transaction. Undo restores the exact pre-move state, including special flags, objective progress, random generator state, currency, and pending chain reactions.
- Win condition is explicit per level: e.g., clear target families, fill a collection tray, create target-tier coins, or clear the board.
- Loss/blocked condition is explicit. Core campaign has no timer-based loss.
- No random coin spawn may occur unless the level’s spawn distribution and fairness model are defined and the level remains solvable under the advertised rules.

## 7. Original mechanics roadmap

### MVP
- Standard colored/enamel coins
- Capacity-limited stacks and trays
- Merge threshold and chain resolution
- Undo, restart, hint
- 30–50 authored tutorial and campaign levels
- Save/resume, settings, sound/haptics
- Offline play
- Basic analytics/crash reporting with privacy disclosure

### Season 1 — only after core quality gates
- **Frost seal:** a coin becomes movable after a neighboring or adjacent match condition is met.
- **Twin seal:** two linked coins must be moved or released under a clearly taught rule.
- **Mystery coin:** identity is revealed on a defined event; solver accounts for all possible outcomes or the level is explicitly luck-based and kept out of the fair campaign.
- **Vault coin:** requires a stated number of matching merges nearby.
- **Wild enamel:** matches one of a defined set of families, with unambiguous UI.
- **Limited tray:** a temporary extra slot with a clearly shown duration/condition; no surprise timer in relaxed mode.
- **Collection goal:** create specific tiers rather than simply clear the board.

Do not launch all special types at once. Introduce one mechanic at a time, then combine only after the player understands each mechanic.

### Retention features
- Chapter collection and cosmetic unlocks.
- Optional daily puzzle with guaranteed solution.
- Streak rewards that do not punish missed days.
- Weekly themed challenge.
- Optional achievements.
- Cloud save only after consent/account strategy is defined; local-first play must remain available.

## 8. Fairness and difficulty requirements
- Every authored standard level must have a known solution, solver proof, and regression test.
- Generated levels must pass the solver before release to the player.
- Difficulty rises through constrained capacity, deeper planning, and mechanic combinations—not by secretly changing outcomes or blocking valid moves.
- No unannounced spawn or rule changes.
- Hints should suggest a valid move or explicitly say no hint is available; never fabricate a move.
- Restart restores the same initial board unless the level explicitly advertises a new randomized seed.
- If using procedural randomness, persist the seed and generator version for replay/debugging.
- Provide a free recovery path after a verified level-generation failure.

## 9. Monetization and player trust
Recommended initial model:
- Free campaign supported by optional rewarded ads and carefully capped interstitials.
- Rewarded ads are opt-in and grant exactly the advertised reward after verified completion.
- Never show an interstitial during a move, chain resolution, tutorial, or before the first completed level.
- Start with a conservative interstitial cap (e.g., no more than one every 3–5 completed levels, and a session cap); A/B test only if player sentiment remains healthy.
- No ads for children-directed experiences unless policy and consent requirements are met.
- Optional one-time “Remove Ads” purchase; state exactly which ads it removes and whether rewarded ads remain optional.
- Cosmetic coin skins and chapter themes; no pay-to-win randomization.
- Premium currency is optional and not required to complete standard levels.
- Validate purchase receipts through the platform/provider flow; handle pending, restored, canceled, and refunded purchases.
- Include privacy policy, terms, support contact, consent/age-gating assessment, and store-policy review before release.

## 10. Accessibility and localization
- Support dynamic text in Flutter UI; keep text out of baked art where practical.
- Minimum comfortable tap target approximately 48 logical pixels, adjusted for board density.
- Color-blind mode; symbols/rim patterns as redundant signals.
- Reduced motion and haptic controls.
- Screen-reader semantics for menus and key state; test whether gameplay can expose meaningful labels without slowing play.
- Respect system text scaling; avoid clipping on small screens.
- Externalize all player-facing strings; no string concatenation for localization.
- RTL layout readiness and pluralization support.
- Test low-end devices, tablets, different aspect ratios, display cutouts, and large text.

## 11. Quality bar / acceptance criteria
- Player can finish tutorial without external instructions.
- No illegal move changes the board or consumes a resource.
- Every legal move has immediate, clear feedback.
- Undo exactly restores state and currency.
- Save/resume restores the same board, level, seed, objectives, and booster counts.
- A completed level cannot award rewards twice.
- No ads during gameplay or critical transitions.
- The game runs offline for core campaign.
- 60 FPS target on representative mid-range devices; degrade particles/effects gracefully on low-end devices.
- No blocking crash, save loss, soft-lock, false no-moves state, or purchase loss in release candidate.
- All third-party assets have recorded licenses and attribution obligations.
- The visual identity is original and not confusingly similar to the reference product.

## 12. Art and asset pipeline
Create an asset manifest containing: asset ID, file path, dimensions, format, intended use, source/creator, license, localization variants, and compression settings.
- Prefer vector sources for scalable icons and high-resolution transparent PNG/WebP sprites where appropriate.
- Use sprite atlases for coin states and particles; avoid excessive texture swaps.
- Include placeholders only in development; production build must fail CI if required assets are missing.
- Produce light/dark and accessibility variants only where needed.
- Keep source files (SVG/Blender/etc.) alongside exported assets in the project repository.

## 13. Product analytics (privacy-conscious)
Track only events needed to understand quality and progression:
- tutorial_started/completed/abandoned
- level_started/completed/failed/restarted
- legal_move_count, undo_used, hint_used, booster_used
- verified_no_moves_state
- session_started/ended
- ad_requested/loaded/shown/completed/failed
- purchase_started/completed/failed/restored
- save_restore_success/failure
Do not log raw personal data. Document retention, consent, deletion, and vendor sharing. Analytics must never control puzzle fairness.

## 14. Release roadmap
1. **Prototype:** one polished level, core move/merge, undo, sound, and visual identity.
2. **Vertical slice:** onboarding, 10 levels, save/resume, solver validation, pause, accessibility options.
3. **MVP:** 30–50 verified levels, progression, basic economy, QA automation, crash reporting.
4. **Closed test:** device matrix, telemetry review, playtests, store compliance.
5. **Soft launch:** tune difficulty and ad cadence using transparent metrics and qualitative feedback.
6. **Global release:** localization, store assets, support workflow, rollback strategy.
7. **Live operations:** only add events/mechanics after stability and retention baselines are understood.

## 15. Reference research and limitations
The reference game’s Google Play listing describes color sorting, matching/merging, special coin types (hidden, linked, ice), boosters, relaxed no-timer play, and increasing complexity. Public reviews include complaints about incorrect no-moves states, potentially unwinnable random outcomes, intrusive ads, and bugs. These are qualitative signals, not independently verified defects in all sessions.

- Google Play listing: https://play.google.com/store/apps/details?id=com.pocket.sort.coin.puzzle.game&hl=en_IN
- AppBrain listing/review aggregation: https://www.appbrain.com/app/com.pocket.sort.coin.puzzle.game
- Flame documentation: https://docs.flame-engine.org/latest/index.html
- Flame 3D package status: https://github.com/flame-engine/flame/blob/main/packages/flame_3d/README.md
