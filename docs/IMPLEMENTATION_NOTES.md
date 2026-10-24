# Implementation Notes

Status as of 2026-10-24. Source specs: `design.md`, `features-and-flows.md`, `architecture.md` (repo root).

## Decisions

| Topic | Decision | Why |
|---|---|---|
| Renderer | Flame, **2.5D**: procedurally drawn enamel coins rasterised once per size into a sprite cache | Recommended path in architecture.md §1. True 3D (`flame_3d`) is still a separate, time-boxed spike. The board sits behind the `BoardPresenter` port, so changing the renderer leaves the domain untouched. |
| State management | Riverpod 3 (`Notifier`) for app/UI state. Flame owns per-frame transforms only. | architecture.md §8 |
| Persistence | Versioned JSON envelope with a sha256 checksum. Writes go to a temp file, then rename. Keeps a last-known-good `save.bak` and a diagnostic `save.corrupt`. | architecture.md §10, Flow K |
| Move rule | Lift the top run; land on an empty tray or a matching tray; stop when the run reaches K | One consistent, fully deterministic rule (docs/rules.md) |
| Spawns / RNG in play | None. Boards are fixed and proven solvable offline. | "Fair by construction". No hidden randomness, nothing to manipulate. |
| Content | 40 levels: one authored tutorial plus 39 generated from versioned seeds. Each passes the solver, carries a stored solution proof and is re-verified on device and in CI. | design.md §8 |
| Audio | Synthesised in code (`tool/generate_audio.dart`) | Original, no licence obligations |
| Fonts | Fredoka + Nunito (SIL OFL 1.1), bundled | Works offline; credited in-app |
| Ads / billing / analytics | Behind ports. The adapters shipped now (`UnconfiguredAds`, `UnavailableBilling`, `ConsoleAnalytics`) report "unavailable" honestly. | No account IDs exist yet. Faking success is prohibited (architecture.md §17.8). |

## Layer map

```
lib/domain/          pure Dart: model, rules, solver, generator, economy, progression
lib/application/     GameSession, GameplayController, ports, providers, ad policy, purchases
lib/data/            save repository + file store, level pack codec/repository
lib/infrastructure/  audio, haptics, analytics, crash, ads, billing adapters
lib/game/            Flame renderer (BoardPresenter impl), components, coin art
lib/features/        Flutter screens and overlays
tool/                generate_levels, validate_levels, check_assets, generate_audio, brand assets
```

## Requirement coverage

Done and tested: canonical rules; merge chains; veiled and frost coins; the solver with honest statuses; level validation (schema, proof replay, independent re-solve); undo, restart and hint; the extra-tray booster; atomic, idempotent completion and rewards; the transaction ledger; daily gift (no streak); cosmetic finishes; save, resume, backup and corruption recovery; migration framework; tutorial (Flow A); every flow C–H; the blocked-board overlay (shown only after the authoritative check); dead-end banner (proof-based); interstitial policy (caps, never during play or the tutorial); rewarded-ad and purchase idempotency; reduced motion; colour-blind assist (rim patterns + letters); screen-reader layer over the board; localisation pipeline (ARB); debug overlay (FPS, state hash, legal moves, seed, revision); CI workflow.

Not done (needs a decision, an account or real devices):

1. **Ad SDK and store billing**: choose providers, configure product IDs, then implement `AdsPort` and `BillingPort` adapters with server/receipt validation. The UI and idempotency logic are already in place.
2. **Analytics and crash vendor**: pick vendors and do a privacy review. The ports are allow-listed and consent-gated.
3. **Application ID**: still `com.example.coin`. Change it to your real reverse-DNS ID before any store upload, and set up release signing.
4. **Support contact, privacy policy URL and terms**: placeholders say so explicitly.
5. **Additional locales**: only English is shipped. Strings are externalised and use plurals.
6. **Daily puzzle and events**: post-MVP. The generator and solver already support seeded, validated boards.
7. **Performance on real devices**: the 60 FPS target still needs verifying on a mid-range Android phone in `--profile` mode. The debug emulator showed about 35 FPS in debug mode, which is not representative.
8. **Golden tests and a device matrix**: not added yet.
9. **True 3D spike**: not started (intentionally).

## Commands

```sh
flutter pub get
flutter analyze
flutter test test                              # 60 tests: domain, application, data, level pack
dart run tool/validate_levels.dart             # all 40 levels verified
dart run tool/check_assets.dart
dart run tool/generate_levels.dart             # regenerate pack (deterministic)
dart run tool/generate_audio.dart              # regenerate sfx/music
flutter test tool/render_brand_assets_test.dart && tool/apply_brand_assets.sh
flutter build apk --release
```
