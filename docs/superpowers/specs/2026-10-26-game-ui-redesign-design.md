# Game UI Redesign — Design

**Date:** 2026-10-26
**Status:** Phases 1–5 built 2026-10-26. The user skipped Q&A, so every decision here is the builder's call.

**Left over:** the pause sheet's toggles and the info screens (privacy/support/credits) still use stock Material switches and app bars.
**Builds on:** design.md §4–5 (visual direction, screens) and the onboarding/FTUE spec of the same date.

## 1. Why

The board, coins and city scenery already look like a game. Everything around them still reads like a utility app:

- Home is a logo, a text card and four stock Material icons in brown circles.
- Chapters is a card list rather than a journey.
- Shop is paragraphs of text with price pills.
- Navigation is "push a screen, press back".

Top casual puzzle games (Royal Match, Coin Sort, Gardenscapes) have a shared grammar that players recognise instantly:

- a persistent bottom tab bar with a raised Home/Play;
- a full-bleed scene behind the hub;
- chunky glossy buttons with a darker bottom lip;
- ribbon title banners;
- a currency pill with a "+" button;
- side-rail event buttons with "!" badges;
- a winding level map.

We adopt that grammar in Coin Atelier's own warm-gold / walnut identity. Copy no one's art.

**Anti-goals:**
- Dark patterns: fake timers, a fake "X", or an offer popup on launch.
- Breaking the fairness promises in design.md §9.
- Clutter: every hub element must earn its spot.
- Blocking the flow from icon tap to first move. Onboarding still pushes the lesson directly.

## 2. Visual language

| Element | Spec |
|---|---|
| **Game button** (`GameButton`) | Rounded rect, colour ramp top→bottom, 5 px darker "lip" under it, 2 px dark outline, white gloss band on the top 40 %, Fredoka label with a dark 2 px stroke. Pressing sinks it into the lip (translate +3 px) with a light haptic. Variants: green = play/confirm, gold = spend, blue = secondary, red = close/danger, grey = disabled. |
| **Round icon button** (`GameRoundButton`) | Same build, circular. Used for settings, close and the HUD. |
| **Panel** (`GamePanel`) | Cream parchment body with a gold rim and an optional **ribbon banner** title overlapping the top edge (red ribbon with folded tails). |
| **Currency pill** (`CurrencyPill`) | Dark glass pill showing coin icon + amount, with a small green "+" button that opens Shop. |
| **Badge** | Red dot with white "!" or a count, top-right of rail and tab icons. |
| **Icons** (`GameIcon`) | Code-painted, glossy, two-tone with dark outline. They replace Material icons everywhere a player sees them. Set: play, home, map, shop (treasure chest), cabinet (trophy), cities (globe with pin), gift, settings (gear), hint (bulb), undo, extra tray, restart, pause, lock, check, close, star, video, no-ads, sound, music, vibrate, back. |
| **Typography** | Fredoka for all game labels (titles stroked with a drop shadow); Nunito only for body copy. |
| **Colour** | Existing tokens, plus button ramps (green, gold, blue, red) and ribbon red `#D6423B → #9E2A25`. |

Motion stays within design.md budgets. Under reduced motion there is no idle pulse or bounce.

## 3. Information architecture

```
App shell (persistent bottom bar, 5 tabs; Home is selected on launch)
├── Shop        – offer tiles (hint pack, extra tray, free video, remove ads, restore)
├── Cabinet     – coin families album + finishes
├── HOME (center, raised)
│     top HUD: currency pill (+ → Shop tab) · settings gear (→ settings sheet)
│     left rail: Daily gift chest (! badge when ready)
│     center: chapter ribbon + progress toward chapter end
│     bottom: big green "Level N" button (pulses)
├── Map         – winding level path, chapter banners, auto-scroll to current level
└── Cities      – themes (city scenes)
Gameplay = full-screen route above the shell (no tab bar)
Settings = modal sheet (from Home gear and the in-game pause sheet)
```

- Tabs keep their state (`IndexedStack`).
- Back on a non-Home tab returns to Home. Back on Home exits.
- The lesson-first flow is unchanged: the boot screen pushes the lesson over the shell.

## 4. Screens

1. **Home**
   - Full-bleed active city scene; the existing `AtelierBackground` is kept.
   - Top HUD with safe area.
   - Left rail: the gift chest. It glows and wobbles when ready; tapping claims with a reward toast and sound.
   - Center: the chapter ribbon "Chapter 3 · Veiled Vault", a progress bar with a sealed chest at its end, and "7 / 10".
   - Bottom: the Level button above the tab bar.
   - When the whole campaign is complete, the button reads "All levels done" and opens the Map.

2. **Map**
   - Each level is a coin-shaped node on an S-curve path: 5 per row, alternating direction.
   - Node states:
     - done: gold with a check;
     - current: green, with a pulsing marker and a bouncing pointer;
     - locked: grey with a lock;
     - hard/expert: red/purple rim with a badge.
   - Tapping a reachable node plays it; tapping a locked one nudges and shows a toast.
   - A chapter ribbon heads every 10 levels.
   - The map opens scrolled to the current level.

3. **Shop**
   - 2-column grid of tiles. Each tile has a large painted icon, a title, a short line and a gold price button.
   - Ribbon section titles.
   - "Free with a video" tile in blue.
   - The store section (remove ads, restore) sits at the bottom.
   - The existing economy and purchase logic is kept unchanged.

4. **Cabinet and Cities** — restyled with panels, ribbons and game buttons. Their content and logic are unchanged.

5. **Settings sheet**
   - Panel with a ribbon title.
   - Rows for sound, music, haptics, reduced motion, colour-blind, language, analytics consent, privacy/help links and reset.
   - Each row has an icon and a game-style toggle.

6. **Gameplay**
   - HUD round buttons and the pause button use `GameIcon`.
   - Pause and win sheets use `GamePanel` + `GameButton`.
   - Board, deal button and layout are unchanged.

## 5. Build phases (each ends with screenshots and green tests)

1. Design system: `GameIcon`, `GameButton`, `GameRoundButton`, `GamePanel`/ribbon, `CurrencyPill`, `Badge`.
2. App shell + Home.
3. Map.
4. Shop, Cabinet, Cities, Settings sheet.
5. Gameplay HUD icons, pause/win sheets.

## 6. Non-goals

- New mechanics or economy changes.
- Raster/vector art files.
- Events, leaderboards and avatars (they need live ops).
- Changing the board renderer.
