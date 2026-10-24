# Production Architecture — Coin Atelier (Flutter + Flame)

**Architecture goal:** deterministic, testable, offline-first puzzle game with a clean boundary between game rules, rendering, persistence, platform services, and monetization.

## 1. Important engine decision: 2.5D vs true 3D

Flame is primarily a 2D game engine with a component system, game loop, sprite/animation support, effects, and input handling. The `flame_3d` package exists but is explicitly experimental and depends on Flutter GPU/Impeller; its platform support and limitations must be reviewed before production commitment.

**Recommended production path:** use Flame for the puzzle board and build a polished **2.5D presentation** using layered coin sprites, vector bevels, shadows, lighting highlights, particles, and perspective transforms. This is the safest route for a casual sorting puzzle and broad Flutter platform reach.

If the product requirement truly means interactive mesh-based 3D with camera, lights, materials, and 3D physics, run a time-boxed technical spike for `flame_3d` or a dedicated 3D runtime before committing. Do not promise stable true 3D on every platform based only on a demo. The architecture below isolates rendering so the domain model survives a renderer change.

References:
- Flame docs: https://docs.flame-engine.org/latest/index.html
- Flame components: https://docs.flame-engine.org/latest/flame/components/components.html
- Experimental flame_3d README: https://github.com/flame-engine/flame/blob/main/packages/flame_3d/README.md

## 2. High-level architecture

```text
Flutter App Shell
 ├── Navigation / lifecycle / theme / localization
 ├── Flutter screens and overlays (home, pause, shop, settings, dialogs)
 └── GameWidget
      └── Flame Presentation Layer
           ├── BoardRenderer / StackComponent / CoinComponent
           ├── InputRouter / AnimationCoordinator / Particles / Audio cues
           └── Presentation events only; no authoritative puzzle rules
                    │ commands / immutable snapshots / events
                    ▼
              Application Layer
              ├── StartLevel / SubmitMove / Undo / Restart / Hint
              ├── CompleteLevel / GrantReward / SaveSession
              └── SessionCoordinator / lifecycle coordination
                    │
                    ▼
              Domain Layer (pure Dart; no Flutter/Flame imports)
              ├── BoardState / StackState / CoinState / LevelDefinition
              ├── RulesEngine / MoveValidator / MergeResolver
              ├── ObjectiveEvaluator / LegalMoveEnumerator
              ├── Solver / LevelValidator / Difficulty metrics
              └── Economy rules / progression invariants
                    │
                    ▼
              Data + Infrastructure
              ├── LocalSaveRepository / schema migrations / backup
              ├── LevelRepository / bundled level packs
              ├── Asset manifest / audio
              ├── AdsAdapter / BillingAdapter / AnalyticsAdapter
              └── Crash reporting / feature flags / optional cloud sync
```

## 3. Architectural principles

- Domain logic must be pure Dart and independent of Flame, Flutter widgets, network, ads, and storage.
- One canonical `RulesEngine` powers gameplay, hints, no-moves detection, solver, and QA tools.
- Immutable domain snapshots; changes occur through validated commands and deterministic reducers.
- Animations are presentation only. They cannot mutate rules or award currency.
- Local-first: core campaign and saves work offline.
- Services are accessed through interfaces and injected implementations.
- External SDK callbacks are treated as untrusted asynchronous events; validate session tokens and idempotency keys.
- Version all level definitions, save schema, RNG algorithm, and solver format.
- Remote config may adjust safe presentation/monetization parameters, never puzzle legality or level solvability.
- Avoid premature microservices/backend dependence. MVP can ship without a custom backend.

## 4. Suggested repository structure

```text
coin_atelier/
├── android/
├── ios/
├── assets/
│   ├── images/
│   │   ├── coins/
│   │   ├── board/
│   │   ├── effects/
│   │   └── ui/
│   ├── audio/
│   ├── fonts/
│   └── levels/
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── coin_atelier_app.dart
│   │   ├── app_router.dart
│   │   ├── app_lifecycle_coordinator.dart
│   │   ├── theme/
│   │   └── localization/
│   ├── core/
│   │   ├── result.dart
│   │   ├── errors.dart
│   │   ├── logging/
│   │   ├── ids/
│   │   └── clock.dart
│   ├── domain/
│   │   ├── model/
│   │   ├── rules/
│   │   ├── commands/
│   │   ├── events/
│   │   ├── objectives/
│   │   ├── solver/
│   │   ├── progression/
│   │   └── economy/
│   ├── application/
│   │   ├── session/
│   │   ├── use_cases/
│   │   ├── state/
│   │   └── ports/
│   ├── data/
│   │   ├── save/
│   │   ├── levels/
│   │   ├── migrations/
│   │   └── codecs/
│   ├── game/
│   │   ├── coin_atelier_game.dart
│   │   ├── board/
│   │   ├── components/
│   │   ├── input/
│   │   ├── animations/
│   │   ├── audio/
│   │   └── presentation_events/
│   ├── features/
│   │   ├── onboarding/
│   │   ├── home/
│   │   ├── chapter_map/
│   │   ├── gameplay/
│   │   ├── collection/
│   │   ├── shop/
│   │   ├── settings/
│   │   └── support/
│   └── infrastructure/
│       ├── ads/
│       ├── billing/
│       ├── analytics/
│       ├── crash_reporting/
│       ├── remote_config/
│       └── cloud_save/      # optional post-MVP
├── test/
│   ├── domain/
│   ├── application/
│   ├── data/
│   ├── game/
│   ├── golden/
│   └── integration/
├── tool/
│   ├── validate_levels.dart
│   ├── generate_level_report.dart
│   └── check_assets.dart
├── docs/
│   ├── design.md
│   ├── features-and-flows.md
│   └── architecture.md
├── analysis_options.yaml
├── pubspec.yaml
└── README.md
```

Keep the number of packages/dependencies reasonable. Extract Dart packages only when there is a real independent boundary or build-time benefit.

## 5. Domain model

Use immutable values and explicit IDs. Names are illustrative.

```dart
enum SpecialCoinType { none, frosted, linked, mystery, wild, vault }

class CoinState {
  final String id;
  final String familyId;
  final int tier;
  final SpecialCoinType specialType;
  final Map<String, Object?> specialState;
  final String? linkGroupId;
  final bool isRevealed;
}

class StackState {
  final String id;
  final List<CoinState> coins; // define top/bottom convention once
  final int capacity;
  final String? acceptedFamilyId;
}

class BoardState {
  final List<StackState> stacks;
  final int moveCount;
  final int rngState;
  final ObjectiveState objective;
  final int rulesVersion;
}

class LevelDefinition {
  final String id;
  final int version;
  final int rulesVersion;
  final BoardState initialState;
  final ObjectiveDefinition objective;
  final Set<SpecialCoinType> allowedSpecials;
  final int seed;
  final RewardDefinition reward;
}
```

Implementation notes:
- Prefer generated immutable classes or carefully enforced `final` fields and unmodifiable collections.
- Avoid storing Flame component references in domain objects.
- Use typed special-state models instead of arbitrary maps once mechanics stabilize.
- Define canonical serialization and stable ordering.
- IDs should be deterministic in tests and safe for save migration.

## 6. Rules engine contract

Suggested interfaces:

```dart
abstract interface class RulesEngine {
  ValidationResult validateMove(BoardState state, MoveCommand command);
  MoveResolution applyMove(BoardState state, MoveCommand command);
  List<MoveCommand> legalMoves(BoardState state);
  ObjectiveStatus evaluateObjective(BoardState state, ObjectiveDefinition objective);
  BoardStatus evaluateBoard(BoardState state);
}

class MoveResolution {
  final BoardState nextState;
  final List<DomainEvent> events;
  final BoardState undoSnapshot;
}
```

`validateMove` must be side-effect-free. `applyMove` only accepts a validated command and returns a complete resolution. Do not let UI code mutate stacks directly.

### Transaction order
1. Validate command.
2. Capture immutable pre-move snapshot.
3. Apply move.
4. Resolve special rules and merges in canonical order.
5. Evaluate objective and legal moves.
6. Validate invariants.
7. Commit state and event log.
8. Persist.
9. Publish presentation events for animation/audio.
10. Show overlays only after state is committed.

If persistence fails, keep the last committed snapshot in memory and retry safely; do not award a reward twice.

## 7. Solver and level validation

### Requirements
- Exact solver for small/medium boards; bounded search with explicit result status: `solved`, `unsolved_proven`, `unknown_budget_exceeded`, `invalid_level`.
- Never interpret `unknown_budget_exceeded` as “impossible”.
- Use canonical state hashing that includes every rule-relevant flag, objective state, and RNG state.
- Search optimizations may include move ordering, symmetry reduction, memoization, and dead-state detection, but must preserve correctness.
- Solver and runtime legality share the same rule definitions.
- Store a solution proof/path hash for authored campaign levels.
- Generated levels must be solved/validated before exposure to players.
- Build a command-line level validation tool for CI.

### Generator policy
- Prefer deterministic generation from a persisted seed and generator version.
- Generate candidate -> validate schema -> solver check -> difficulty estimate -> accept/reject.
- Have a safe authored fallback when generation repeatedly fails.
- Do not generate random spawns during a level unless the rules explicitly model them and the fairness proof covers them.

## 8. Application layer

Use cases coordinate domain state and repositories. Examples:
- `LoadPlayerProfile`
- `StartLevel`
- `ResumeLevel`
- `SubmitMove`
- `UndoLastMove`
- `RestartLevel`
- `RequestHint`
- `CompleteLevel`
- `ClaimLevelReward`
- `PersistSession`
- `ChangeSettings`
- `PurchaseEntitlement`
- `RestorePurchases`

A `SessionCoordinator` owns the current level session, command serialization, app lifecycle, and stale-action cancellation. The game renderer subscribes to immutable snapshots/events.

State management choice: Riverpod, Bloc, or another established Flutter approach is acceptable. Pick one and use it consistently for app/UI state. Do not put high-frequency per-frame rendering state into global app state; Flame components own presentation-only transforms and animation progress.

## 9. Flame presentation architecture

### Responsibilities
- Render stacks, coins, board surfaces, selection highlights, legal targets, particles, and movement/merge animations.
- Convert pointer events into domain commands.
- Subscribe to domain transition events and animate the committed result.
- Maintain a mapping from stable domain IDs to current visual components.
- Handle resizing and coordinate transforms.
- Pause rendering/audio appropriately when app is backgrounded.

### Must not
- Decide whether a move is legal independently.
- Mutate currency, objective progress, level completion, or saved board state.
- Infer “no moves” from what is visually on screen.
- Use animation completion as the only source of truth for gameplay state.
- Store authoritative coin state only inside components.

### Rendering plan
- MVP: 2.5D sprites/vector art, layered rims, gradients, shadows, particles, eased movement, subtle scale/rotation.
- Use `GameWidget` embedded in Flutter screens and Flutter overlays for menus, settings, shop, pause, and accessibility.
- Use a fixed logical board coordinate system and responsive mapping to viewport.
- Pool/reuse particle components if profiling shows allocation pressure.
- Reduce particle count and shadow complexity on low-end devices.
- Add debug overlay for FPS, state hash, selected stack, legal-move count, level seed, and last domain event.

### True 3D decision gate
Before any production true-3D commitment, prototype:
1. target Android/iOS devices and graphics backends;
2. required mesh/material/light/camera features;
3. memory, battery, thermal, and frame-time profile;
4. pause/resume and device compatibility;
5. fallback renderer strategy;
6. packaging and plugin maintenance risk.
If this spike fails the target bar, retain 2.5D Flame rendering or embed a dedicated 3D runtime behind `BoardRenderer`.

## 10. Persistence and save integrity

### Save contents
- schema version
- profile/progression
- settings and consent state
- active level ID/version
- full committed `BoardState`
- undo snapshot(s) within a bounded history
- level seed and generator version
- booster inventory
- transaction ledger cursor
- completion/reward idempotency records
- checksum or integrity marker

### Save strategy
- Local-first repository with atomic write or write-temp-then-rename pattern where platform supports it.
- Keep last-known-good backup.
- Save after each committed move and important lifecycle transition; debounce non-critical settings writes.
- Never serialize animation progress as authoritative state.
- Migrations are sequential, versioned, and tested against fixture saves.
- Avoid storing sensitive personal data. Cloud save, if added, requires conflict resolution and clear privacy disclosures.

## 11. Infrastructure adapters

### Ads
`AdsPort` should expose load/show/result and reward validation without leaking SDK types into domain code. Inject a no-op/mock adapter in tests. Apply consent, frequency caps, placement rules, and app lifecycle handling.

### Billing
`BillingPort` handles product catalog, purchase flow, restore, entitlement updates, pending/canceled/refunded states. Use platform/store price strings. Reward/entitlement application must be idempotent. Verify purchases according to the selected store/provider requirements.

### Analytics
`AnalyticsPort` accepts typed, allowlisted events. No raw email, payment data, or unnecessary device fingerprint. Events should never determine game rules.

### Crash reporting
Capture exception class, app version, level ID/version, rules version, and non-sensitive state hash. Avoid logging full serialized board/profile unless scrubbed and explicitly justified.

### Remote config
Use for safe cosmetic/live-ops settings and ad frequency caps. Cache last known good config. Defaults must be safe offline. Remote values must be schema-validated and cannot make standard levels unsolvable.

### Cloud save (optional)
Add only after MVP. Define account identity, conflict resolution, offline queue, data deletion, and recovery UX before enabling.

## 12. Performance and memory budgets

Targets to validate on real devices:
- 60 FPS on representative mid-range Android devices for normal board states.
- Input-to-visible-feedback target under 100 ms under typical load.
- No synchronous file/network operations on UI/game loop.
- Load only required level/coin assets; cache and dispose intentionally.
- Avoid per-frame object allocation in hot update/render loops where profiling identifies pressure.
- Respect image dimensions and texture memory limits; atlas assets where beneficial.
- Stress test long sessions, repeated level transitions, app backgrounding, and low-memory conditions.
- Add performance instrumentation before premature optimization.

## 13. Testing strategy

### Unit tests
- move validation and all rule edge cases
- merge/chain ordering
- special coin state transitions
- objective evaluation
- legal move enumeration
- solver correctness on known small boards
- save codec and migrations
- rewards/economy idempotency
- deterministic seeded generation

### Property/model-based tests
- every accepted move preserves board invariants
- no coin is duplicated or lost unless a defined merge consumes it
- invalid move leaves state byte-for-byte equivalent
- undo followed by reapply yields equivalent state
- all legal moves are accepted by validator
- solver's returned move is legal
- standard levels have a solution within configured budget

### Integration tests
- tutorial -> level complete -> next level
- background/kill/relaunch during each session state
- save failure and recovery
- ad unavailable, closed early, reward complete
- purchase pending/canceled/restored
- repeated win callbacks
- stale callbacks after leaving a level

### Golden/visual tests
- home, gameplay, pause, blocked state, win overlay
- small/large screens, safe areas, text scale, color-blind palette, reduced motion
- sprite atlas and coin state variants

### Manual device matrix
- low-end Android, mid-range Android, high-refresh device, tablet
- iOS when release target is enabled
- offline/poor network
- audio focus interruptions, rotation if supported, background/foreground, low memory

## 14. CI/CD and release gates

Every pull request:
1. format check
2. static analysis/lints
3. unit and property tests
4. level pack schema validation
5. solver validation of all standard levels
6. required asset check
7. golden tests where stable
8. dependency/security/license scan
9. build debug/release variants

Release candidate:
- integration tests on real devices
- crash-free and performance review
- privacy/data safety/store declarations review
- billing and ad sandbox tests
- accessibility review
- backup/migration tests
- signed build and reproducible version metadata
- rollback plan for content/config issues

## 15. Dependency policy
Use current stable, compatible package versions at implementation time; do not blindly copy version numbers from an old prompt. Pin or constrain dependencies intentionally, review changelogs, and commit the lockfile for the app. Separate SDK adapters so an ad/billing provider can be replaced without rewriting gameplay.

Likely categories:
- `flame`
- state management: choose one (e.g. Riverpod or Bloc)
- local persistence: choose a suitable robust local store after profiling requirements
- audio: Flame audio bridge or compatible audio package
- billing: official store billing integration/package
- ads: selected compliant mobile ad SDK
- analytics/crash reporting: selected provider with privacy review
- localization: Flutter localization tooling

Avoid adding all candidates; choose the smallest set that satisfies requirements.

## 16. Definition of production-ready
The app is not production-ready merely because it builds. It must satisfy:
- domain rules isolated and deterministic
- verified campaign level pack
- no false no-moves states in regression suite
- safe save/recovery/migration
- idempotent rewards and purchases
- offline campaign
- accessible, responsive UI
- no in-level interstitial ads
- target-device performance
- crash/diagnostic observability without excessive data collection
- legal asset provenance and store compliance
- support and incident/rollback process

## 17. AI implementation instructions
When an AI coding agent receives this repository:
1. Read all three docs before coding.
2. Inspect the existing repo and report its current state; do not overwrite working code blindly.
3. Produce a milestone plan and identify the true-3D decision as a technical spike, not an assumption.
4. Implement in vertical slices; keep the app runnable after each milestone.
5. Start with a deterministic domain engine and unit tests before visual polish.
6. Build one complete level end-to-end, then the solver and level validation pipeline, then content and presentation.
7. Never use mock buttons or TODO placeholders for features marked complete.
8. Never fabricate analytics, purchase, ad, or save success.
9. Do not use network calls in the domain layer.
10. Run formatting, analyzer, tests, level validation, and release build; report exact commands and actual results.
11. If a requirement conflicts with a platform/engine limitation, explain the trade-off and propose a tested alternative instead of silently pretending it works.
12. Keep implementation notes, asset licenses, and test evidence current.
