# Onboarding (FTUE) & ASO — Design

**Date:** 2026-10-26
**Status:** Built 2026-10-26 (user skipped Q&A; calls below are the builder's, marked *[call]*). §4–5 are launch checklists, not code.
**Extends:** design.md §5B (onboarding), §9 (trust), §13 (analytics); features-and-flows.md Flow A.

## 1. Intent

A new install comes from a store page that shows coins being sorted. The first
session must deliver exactly that promise within seconds, teach only what is
needed when it is needed, and never ask for anything (consent, rating,
permission) before the player has had a win. A smooth first session drives
D1 retention, star rating and Android vitals — the three things the store
algorithm and listing conversion depend on.

**Success targets** (GameAnalytics 2026: median D1 ≈ 22 %, top-10 % ≈ 40 %):

| Metric | Target |
|---|---|
| Icon tap → first coin move | ≤ 10 s on a mid-range phone |
| Tutorial (level 1) completion | ≥ 90 % of starts |
| Levels 1–5 completion each | ≥ 90 % |
| D1 / D7 | ≥ 35 % / ≥ 10 % |
| Cold start (TTID) | < 2 s typical, never ≥ 5 s (Android vitals "excessive") |
| Crash / user-perceived ANR | < 1.09 % / < 0.47 % (Play bad-behaviour thresholds) |

**Anti-goals:** an ad, account, name prompt, consent dialog or permission prompt
before the first move; a review prompt behind a "Do you like us?" pre-question
(forbidden by Play); a skippable core-move lesson; tutorials that block the
player after a restart.

## 2. What exists (2026-10-26)

- Boot → `WelcomeScreen` (brand + "Start the lesson") → scripted level 1
  (move → undo → redo → fuse → finish) with glowing stacks and a callout.
- One-time intro cards: fill (L2), deal (L3), forge (L11), veiled (L21), frost (L31).
- Hint/Extra tray/Restart disabled in the tutorial; tutorial grants hints.
- `tutorialAbandoned` is declared but never logged; there is no per-step
  lesson event. Analytics consent exists only as a Settings toggle (off), so
  in practice no funnel data is ever collected.
- No in-app review, no coach marks for Hint / Extra tray.

## 3. The flow

```
Install → Splash (brand, ≤ 2 s) → LEVEL 1 lesson (auto-start, no welcome gate)
   hand pointer: tap source → tap target → Undo → … → finish
   win: +hints, "Play next"
→ LEVEL 2  (fill intro card) · Hint coach tip · idle nudge after 10 s
→ LEVEL 3  (deal intro card) · idle nudge
   Next → one-time "Help improve the Atelier?" privacy card (Yes / No thanks)
→ LEVELS 4–5 idle nudge · first interstitial eligible only after L3 (existing policy)
→ LEVEL 6+ Extra-tray coach tip (first time player owns one)
→ LEVEL 12 / 45 / 120 win → Next → in-app review request (quota-guarded)
```

### 3.1 Straight-to-play first run
The first run skips the welcome screen: boot shows Home and immediately pushes
the level-1 lesson, so Back from the lesson lands on Home (never a dead end).
The lesson's first callout carries the welcome line ("Welcome to the Atelier!")
in front of the move instruction. *[call]* The separate welcome screen is
deleted; its brand moment moves to the splash, which already shows the mark.
If the app is killed mid-lesson, the next launch restarts the lesson the same
way (the lesson session is resumable as today).

### 3.2 Hand pointer (lesson)
For every scripted step a gloved-hand pointer shows exactly what to tap:

- move step, nothing selected → hand taps the **source** tray;
- move step, source selected → hand glides to and taps the **target** tray;
- undo step → hand taps the **Undo** button.

It loops (tap pulse 900 ms, glide 450 ms), sits above the tray's top coin, never
intercepts touches, and hides while an intro card or the win sheet is up.
Reduced motion: static hand, no glide. *[call]* No full-screen dim — the
existing glowing focus trays already isolate the targets and dimming hides the
board the store screenshot promised.

### 3.3 Idle nudge (levels 2–5)
If the player makes no input for 10 s on levels 2–5, the solver's next move is
shown with the same hand (source → target, or Deal), free of charge. Any input
hides it and restarts the timer. Shown at most 3 times per level. Never on
level 6+ (Hint takes over; it is a paid/earned tool there).

### 3.4 Coach tips (one time each)
A small speech bubble above a HUD button, dismissed by tapping anywhere or by
using the button. Stored in `seenIntroductions` (`coach_hint`,
`coach_extraTray`) so it never repeats, including across reinstall-restores.

| Tip | When | Text |
|---|---|---|
| Hint | first non-tutorial level, Hint count > 0 | "Stuck? Hint shows a move that keeps the level solvable." |
| Extra tray | first level ≥ 6 with Extra tray count > 0 | "Out of room? Add an extra tray for this level." |

Never shown together with an intro card; the intro card wins and the tip waits.

### 3.5 Privacy card (analytics consent)
After the player taps **Next** on the level-3 win sheet (once per install):
a bottom sheet — "Help improve the Atelier? Share anonymous level and session
statistics. No personal data. You can change this in Settings." with
**Share stats** and **No thanks** (equal visual weight, GDPR). Result writes
`GameSettings.analyticsConsent`; `privacyAsked` prevents a repeat. Default stays
off. *[call]* Level 3 (after two wins, before the first interstitial is
eligible) matches research guidance to ask after the first win and before the
first ad.

### 3.6 In-app review
Port `ReviewPort.request()`, adapter on the platform review API
(`in_app_review`: Play In-App Review / `SKStoreReviewController`). Policy — all
must hold:

- level just completed for the **first time**, number ∈ {12, 45, 120};
- the attempt had no restart and never hit a blocked board;
- ≥ 120 days since the last request and < 3 requests in 365 days;
- not in the tutorial.

It fires when the player taps **Next** (a natural break, not during the
celebration). That tap skips the interstitial so a review is never stacked on
an ad. No pre-question, never from a button. Logged as `reviewRequested`.

### 3.7 Analytics funnel
New allow-listed events (params: level id, step index, enum names only):
`tutorialStep {level, step}`, `tutorialAbandoned {level, step}` (now logged
when the lesson screen closes unfinished), `idleNudgeShown {level}`,
`coachTipShown {tip}`, `privacyPromptResult {accepted}`,
`reviewRequested {level}`. First use of each mechanic is derived server-side
from the existing `undoUsed` / `hintUsed` / `boosterUsed` events.
*[call]* Time-to-first-move is measured on device with Android vitals /
Firebase Performance once a vendor is chosen, not with a custom event. Watch: step-to-step drop (> 50 % between two steps
= fix it), L1–L20 completion, D1 split by tutorial completers.

## 4. ASO linkage (launch checklist, not code)

**Promise match.** Store screenshot 1 and the preview video show the real
level-1/level-3 board: same trays, coins, Deal button, Paris-style backdrop. The
first 10 s of the video = the lesson's first move and first fuse. Mismatch
lowers install→D1.

**Listing (Play):** title ≤ 30 chars, e.g. *Coin Atelier: Coin Sort Puzzle*;
short description ≤ 80 chars, e.g. *Sort, stack & merge coins. Relaxing offline
puzzle — every level solvable.* Keywords to weave in naturally: coin sort, sort
puzzle, color sort, merge, stack, offline, relaxing, brain game. "Every level
solvable" and "free undo" answer the top complaints in competitor reviews and
are true here.

**Experiments:** Play store-listing experiments, one variable at a time, ≥ 7
days: icon → screenshot 1 → short description. iOS: custom product pages
(e.g. "Paris", "Relaxing") with a deep link that, **after** the lesson, opens
the matching chapter/theme — the lesson is never skipped. Record the page id as
an analytics user property to split the funnel (follow-up; needs deep-link
plumbing).

**Vitals:** keep SDK init (ads, consent, analytics vendor) off the first frame
and off the main thread; nothing network-bound before the first move.

**Ratings:** §3.6. Fix-first: reply to 1–2★ reviews about "no moves" within 48 h
with the solvability guarantee.

## 5. Compliance placement (when vendor SDKs land — not in this build)

Order in the flow, all after level 1:

1. **Age screen** (neutral, year picker) before any ad SDK request — required
   if declared "mixed audience" for Families; under-13 → child-directed ads
   (G rating, no ad ID). Alternative: 13+ only (counsel decision).
2. **UMP/GDPR form** (`loadAndPresentIfRequired`) before the first ad request,
   at the level-3 Next, replacing the privacy card in EEA/UK.
3. **ATT** (iOS) pre-prompt with a single Continue button after the level-3 win,
   then the system prompt.
4. **Notifications** (Android 13+) only from an action such as "Remind me when
   my daily gift is ready", never at launch.
5. Settings → "Privacy options" to change any of the above.

## 6. Non-goals

Account/login, name entry, tutorial skip, A/B framework, remote config,
vendor SDK integration, deep-link routing, store assets.

## 7. Left to the builder

Bubble/hand art (draw in code, match `AtelierColors`); exact animation curves;
widget placement for anchoring tips to HUD buttons; persistence field names.
