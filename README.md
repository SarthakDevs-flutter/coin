# Coin Atelier

An original, offline-first coin sorting and fusing puzzle built with Flutter and Flame.
Every level ships with a verified solution. Undo is free and unlimited. There are no timers and no ads during play.

- **Product spec:** `design.md`, `features-and-flows.md`, `architecture.md`
- **Canonical rules:** `docs/rules.md`
- **Status, decisions and gaps:** `docs/IMPLEMENTATION_NOTES.md`
- **Asset provenance:** `assets/ASSET_MANIFEST.json`

## Run

```sh
flutter pub get
flutter run
```

In debug builds, Settings → Debug → *Developer overlay* shows FPS, the state hash and the legal-move count. It also unlocks every level on the chapter map for QA.

## Verify (same steps as CI)

```sh
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test test
dart run tool/validate_levels.dart
dart run tool/check_assets.dart
```
