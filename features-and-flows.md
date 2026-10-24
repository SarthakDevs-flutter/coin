# Product Requirements, Features & End-to-End Flows — Coin Atelier

**Purpose:** Single source of truth for product behavior, screens, user journeys, gameplay rules, edge cases, and acceptance tests.

## 1. Scope and non-goals

### MVP scope
- Android release first, iOS-compatible architecture.
- Offline-first campaign and local save.
- Original coin-sort/merge gameplay.
- Deterministic level data, solver validation, undo/restart/hint.
- Tutorial, chapter progression, settings, basic rewards.
- Optional ads and purchases behind interfaces and feature flags.
- Crash diagnostics and privacy-conscious analytics.

### Non-goals for MVP
- Multiplayer, chat, user-generated levels, competitive leaderboard, account-required play, cloud economy, complex live events, real-money gambling, or an always-online requirement.
- Do not reproduce the reference game's exact levels, art, interface, brand, sounds, store copy, or progression.

## 2. Personas and user needs
- **Relaxed solver:** wants a calm, pause-anytime puzzle with no forced timer.
- **Strategic optimizer:** wants rules that are consistent, undo, and a useful hint.
- **Collector:** wants visible long-term progression and cosmetic rewards.
- **Returning player:** wants reliable continue/resume and no lost progress.
- **Accessibility-focused player:** needs redundant color cues, readable UI, and reduced motion.

## 3. Information architecture

- Boot / recovery
- First-run onboarding
- Home
  - Continue
  - Chapter map
  - Daily puzzle (post-MVP)
  - Collection cabinet
  - Shop
  - Settings
- Gameplay
  - Pause
  - Hint / boosters
  - No-legal-moves recovery
  - Level complete
- Privacy, support, credits, legal pages

## 4. End-to-end player flows

### Flow A — First install
1. App starts and loads local configuration/assets.
2. Validate save schema and migrate if required.
3. If no save exists, create a new local profile with default settings and zero premium currency.
4. Show a brief welcome screen; no forced ad or permission prompt.
5. Start tutorial level 1 with a fixed seed and known solution.
6. Highlight the source stack and explain “tap a stack”.
7. On valid source selection, highlight legal destinations.
8. Player makes the required move; show move and merge feedback.
9. Teach undo, then objective completion.
10. Grant tutorial reward exactly once, save progress, and show home/next level.
**Failure handling:** if asset loading fails, retry or show a recoverable error; if save migration fails, preserve a backup and offer recovery instead of silently resetting.

### Flow B — Returning player
1. Load settings, progression, inventory, active level snapshot, and RNG seed.
2. Validate schema/checksum and active level version.
3. Resume in-progress level if one exists; otherwise show chapter map with Continue.
4. Rebuild the board from serialized domain state—not from animation state.
5. If active level data is incompatible, use a migration or offer a free restart without losing earned progression.
6. Save after each committed move and at app lifecycle boundaries.

### Flow C — Standard gameplay turn
1. Player taps source stack or drags a coin (if drag input is enabled).
2. Input layer translates pointer coordinates into a domain command.
3. Rules engine validates the command against current state.
4. If invalid: no board/economy mutation; provide subtle feedback and optional explanation.
5. If valid: capture undo snapshot; apply move transaction atomically.
6. Resolve deterministic merge/chain effects.
7. Recompute objective and legal moves.
8. Commit final state, increment move count, save snapshot, emit presentation events.
9. Animation layer renders the committed transition. Animations cannot change domain state.
10. If objective complete, enter win state; otherwise continue.
**Invariant:** input received during a critical transition is queued or rejected predictably; it must never create duplicate moves.

### Flow D — Undo
1. Player taps Undo.
2. If no prior committed move exists, show disabled state or clear explanation.
3. Restore exact prior domain snapshot, objective progress, special coin states, seed/state, move count, and booster inventory.
4. Do not refund or deduct currency incorrectly.
5. Save restored state and play a reverse/rewind presentation.
6. Test undo through special coin chains, level completion boundary, app pause, and save/reload.

### Flow E — Hint
1. Player taps Hint.
2. Solver returns a legal move from current state.
3. Highlight source and destination with a short explanation where possible.
4. The player must execute the move; hint never auto-spends a booster unless clearly confirmed.
5. If no hint is found within the configured budget, show “No hint available right now” and offer undo/restart. Do not invent a move.
6. If hint is paid/rewarded, deduct/grant only after confirmed success.

### Flow F — No legal moves
1. After a committed move and all chain effects, enumerate legal moves using the same rules engine.
2. If none exist and objective is incomplete, verify the state with a second independent check in debug/QA builds.
3. Show recovery overlay: Undo (if possible), use available booster, restart, return to map.
4. If the level is expected to be solvable but the generator/level metadata is faulty, flag a diagnostic event and provide a free restart/recovery.
5. Never label a board “impossible” based on a UI guess, timer, animation, or stale state.
6. A paid item must not be the only route out of a generation defect.

### Flow G — Level completion
1. Rules engine determines objective satisfied.
2. Transition to `completed` exactly once; block additional gameplay commands.
3. Calculate deterministic rewards from level config and validated actions.
4. Persist completion and reward transaction atomically.
5. Show win animation, reward breakdown, and Next button.
6. On repeated app launch or duplicate callback, reward cannot be granted twice.
7. Ads may be considered only after the player taps Next/returns to map, subject to frequency caps.

### Flow H — Pause / background / interruption
1. Pause button opens overlay and stops gameplay input.
2. App lifecycle pause persists domain state and pauses engine/audio.
3. On resume, restore audio focus, input state, and rendering from domain snapshot.
4. Do not count wall-clock time as a penalty in relaxed mode.
5. No move should complete twice after interrupted animation.
6. If a reward/ad callback arrives after leaving the level, process only if its session token and eligibility still match.

### Flow I — Rewarded ad
1. Present an explicit opt-in action with exact reward description.
2. Check connectivity, consent, ad readiness, and current game state.
3. If unavailable, explain and provide a non-ad alternative where feasible.
4. Pause gameplay and persist state before showing ad.
5. Grant reward only after the ad SDK confirms completion and the reward token is unused.
6. If user closes early, grant no reward and return safely.
7. Never show a rewarded ad as a fake mandatory error dialog.

### Flow J — Purchase / restore
1. Shop shows price from store billing APIs, not hardcoded locale prices.
2. User selects product and confirms.
3. Billing adapter starts platform purchase.
4. Handle pending, completed, canceled, failed, restored, and refunded states.
5. Validate transaction according to platform/provider requirements.
6. Apply entitlement idempotently; persist transaction reference without logging sensitive payment data.
7. Provide restore purchases where required and a support route for missing entitlements.
8. No gameplay level may become intentionally unsolvable to prompt payment.

### Flow K — Save corruption / migration
1. On startup, parse current save and validate version/checksum.
2. If valid, migrate sequentially if schema version is old.
3. If invalid, preserve the raw file as a diagnostic backup and try last-known-good backup.
4. If both fail, recover profile settings/progression where possible and offer a free restart of the active level.
5. Never overwrite a valid backup with corrupt data.
6. Record non-sensitive error code and schema version.

## 5. Feature specifications

### 5.1 Board and coin model
Each coin:
- `id`: stable unique identifier
- `familyId`: logical match family
- `tier`: merge/progression tier if used
- `specialType`: none/frosted/linked/mystery/wild/vault
- `specialState`: state machine data
- `linkGroupId`: optional
- `isRevealed`: explicit flag
- `metadataVersion`: version for migration

Each stack:
- stable ID
- ordered list of coin IDs (top index convention must be consistent)
- capacity
- stack rule / accepted families
- lock or slot state

### 5.2 Move rules
- One canonical rules implementation determines legality.
- UI uses `legalMoves(state)` to render hints, not separate duplicated rules.
- All command validation must be side-effect-free until accepted.
- Invalid actions must not consume turns, currency, booster inventory, or RNG values.
- Commands are idempotent by action/session ID where asynchronous callbacks exist.

### 5.3 Merge and chain resolution
- Define threshold, compatibility, ordering, and chain behavior in level/rule config.
- Chain resolution must terminate; enforce a defensive maximum iteration count and surface a diagnostic if exceeded.
- Merge result and rewards are deterministic for a given state and config.
- Animation is event-driven from the resolved transition log.

### 5.4 Special coin rules
Every special coin requires a written rule, a state diagram, tutorial trigger, UI states, legal-move behavior, undo behavior, solver support, and test matrix before being enabled.
- Frosted: explicit unlock condition.
- Linked: movement constraint and linked partner behavior.
- Mystery: reveal trigger and fairness handling.
- Wild: permitted match families and merge behavior.
- Vault: explicit counter and completion event.
If any special rule cannot be represented by the solver, it cannot appear in standard campaign levels.

### 5.5 Level content and generation
Level record must include:
- stable `levelId`, chapter, version, difficulty label
- initial board and coin states
- objective and success predicate
- allowed mechanics and boosters
- RNG seed and generator version if applicable
- par moves / expected difficulty metadata (informational, not punitive)
- solver status, solution proof/hash, author/reviewer, test status
- reward config
- content revision and migration policy

Pipeline:
1. Author level or generate from constraints.
2. Validate schema and object IDs.
3. Check reachability and objective consistency.
4. Run solver with bounded search.
5. Require solution for standard campaign; otherwise reject.
6. Store solution proof/hash and run regression tests.
7. Playtest on target screen sizes.
8. Publish via app bundle/content update with versioning.

### 5.6 Progression and rewards
- Campaign unlock follows explicit prerequisites.
- Rewards are deterministic and awarded once per completion record.
- Use transaction ledger for currency changes: transaction ID, source, amount, reason, timestamp.
- Never trust UI counters as authoritative state.
- Daily reward should be optional and forgiving; no streak reset pressure in MVP.

### 5.7 Settings
- SFX, music, haptics
- reduced motion
- color-blind mode
- language
- privacy/consent management
- support/FAQ
- reset local progress with clear confirmation
- restore purchases where applicable

### 5.8 Ads and purchases
- Ads behind interfaces so the game remains playable in tests and offline.
- No ad placements during a level or chain resolution.
- Configurable frequency caps and remote flags, with safe local defaults.
- Never let remote config alter puzzle legality or solvability.
- Consent and age obligations assessed for target markets.
- Store prices/entitlements are provider-driven; never hardcode country prices.

## 6. Required states and state transitions

### Level session
`loading -> ready -> selectingSource -> selectingDestination -> resolving -> ready`
Terminal/overlay transitions:
- `ready -> paused -> ready`
- `resolving -> completed`
- `ready -> blockedRecovery` only after authoritative legal-move check
- `any active state -> interrupted -> ready` after safe restore

Illegal transitions must be rejected. Do not allow a second move while `resolving` unless the command queue has a tested policy.

### Purchase
`idle -> pending -> purchased | canceled | failed | restored`
Pending is not entitlement. Entitlement application is idempotent.

### Save
`clean -> dirty -> writing -> clean | writeFailed`
Keep last-known-good backup; retry safely.

## 7. Error handling matrix

| Situation | Required behavior |
|---|---|
| Asset missing | CI fails; in production show recoverable error/fallback |
| No internet | Core offline campaign works; network-dependent rewards disabled gracefully |
| Ad unavailable | Return to game; no penalty; explain optional reward unavailable |
| Purchase pending | Show pending state; do not grant entitlement prematurely |
| App killed during move | Restore committed domain state; replay or skip visual transition safely |
| Save write fails | Preserve previous valid save; show non-blocking warning if needed |
| Invalid level data | Reject level before play; use safe fallback level |
| Solver timeout | Do not classify as unsolvable; retry with stronger budget/offline validation |
| Duplicate win callback | Grant reward once |
| Corrupt save | Backup, migrate/recover, free active-level restart |
| Stale async callback | Ignore using session/action token |
| Unsupported screen size | Responsive layout and safe-area handling |

## 8. Acceptance test checklist

### Gameplay
- [ ] Every legal move is accepted and every illegal move rejected.
- [ ] Invalid moves do not change state, currency, objective, move count, or RNG.
- [ ] Merge threshold and chain ordering are deterministic.
- [ ] Solver and gameplay engine agree on legal moves.
- [ ] No false “no moves” state across all regression levels.
- [ ] Every standard level has a solution proof.
- [ ] Undo restores exact pre-move state including special coins and RNG.
- [ ] Restart restores the same seed and initial board.
- [ ] Win and reward processing are idempotent.

### Persistence
- [ ] Resume after process kill.
- [ ] Resume after OS background/foreground.
- [ ] Migration from each supported save schema.
- [ ] Recovery from truncated/corrupt save.
- [ ] Save failure never overwrites last-known-good backup.

### UX / accessibility
- [ ] Tutorial is completable with touch and supported drag input.
- [ ] Legal destinations are visible and accessible.
- [ ] Small phone, tablet, cutout, landscape (if supported), large text, RTL.
- [ ] Color-blind mode and reduced-motion mode.
- [ ] SFX/music/haptics preferences persist.
- [ ] Screen reader labels for key Flutter controls.

### Monetization
- [ ] No interstitial in tutorial or active gameplay.
- [ ] Rewarded ad grants exactly one reward only after completion.
- [ ] Early close grants no reward.
- [ ] Purchase canceled/pending/failed/restored/refunded cases.
- [ ] Offline play is not blocked by ad/billing failures.
- [ ] Remove-ads entitlement behaves exactly as store copy states.

### Performance / release
- [ ] 60 FPS target on representative mid-range device.
- [ ] Low-memory handling and asset disposal.
- [ ] Cold launch and resume tested.
- [ ] Crash-free beta target defined and measured.
- [ ] Store privacy, data safety, age rating, ad declarations, billing, and policy review complete.

## 9. Definition of done for a feature
A feature is not done when it merely renders. It is done when:
1. Product rule and edge cases are documented.
2. Domain behavior is unit-tested.
3. UI states and accessibility are implemented.
4. Save/migration behavior is covered.
5. Analytics events are privacy-reviewed.
6. Error/failure states are implemented.
7. Performance and device behavior are checked.
8. Acceptance tests pass.
9. QA notes and screenshots/video evidence are attached to the pull request.
