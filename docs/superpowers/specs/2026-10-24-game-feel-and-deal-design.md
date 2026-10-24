# Game Feel & Deal Mechanic — Design (v2)

**Date:** 2026-10-24
**Input:** a hands-on teardown of the reference game (v1.16.0 on a Samsung A16), screen-recorded at 30 fps and analysed frame by frame. The recordings live outside the repo and are not shipped.
**Boundary (design.md §1):** we copy no name, art, layout, levels, copy or sounds. We study *mechanics, pacing and motion timing* only, and express them in Coin Atelier's own visual language.

## 1. What the reference does (measured)

| Beat | Observation | Timing |
|---|---|---|
| Select | The whole matching top run rises about 0.6 coin-heights. Ease-out, no bounce. | ~100 ms |
| Move | Coins leave **one at a time** in a stream. Each arcs and **tumbles** (flips edge-on mid-air) and lands with a small settle. | ~35 ms stagger, ~200 ms per flight, ~400 ms for a run of 5 |
| Stack full | The destination slot gets a **green outline glow** when it holds K alike | holds ~300 ms before the fuse |
| Fuse | The stack **whitens bottom→top**, **compresses** into one spot, then a **golden burst** (radial glow + expanding ring + star sparkles); the new coin **pops** in | ~1.2 s total |
| Goal collect | A produced target coin **flies to the goal tile** in the HUD; the tile pops and its count ticks down | ~400 ms per coin, staggered |
| Chain | Consecutive fuses show big gold **"Combo ×N!"**: letters type in one by one with a wave, then fade out one by one | ~1.5 s |
| Deal (DROP) | One button sprays a batch of random coins from the button into the columns: fan-out, tumbling, staggered | ~700 ms |
| Modals | Scale 0.6 → 1.08 → 1.0 with fade-in; the backdrop dims | ~250 ms |
| View | Thick 3D discs, ~10 per slot, top-down perspective; only the top face shows a number; ridged edges carry the colour | — |

### Weaknesses we turn into strengths

- **Random deals can make a level unwinnable.** Ours come from a **finite, seeded, visible queue**, and the solver proves every level solvable *including the deals*. A next-deal preview lets players plan.
- **Illegal taps and DROP on a full board give no feedback.** Ours nudge the tray and say exactly why.
- **The space limit is pushed through a timed paid slot; restarting costs a "heart".** Ours: undo and restart are always free, there are no energy gates, and the extra tray is permanent for the level.
- **Colour plus a number on the face only.** Ours: colour + glyph + rim/edge pattern + optional letter, so it stays readable for colour-blind players.

## 2. Decisions

### 2.1 Deal mechanic (new, rules v2)

- A level may define a **deal queue**: an ordered list of batches. Each batch lists, per tray, the coins to drop (ids are fixed in the level data).
- **Deal** is a player action alongside moves:
  - It is legal only when a batch remains **and** every targeted tray has room for its coins.
  - When it isn't legal, the button explains why ("Make room in the highlighted trays").
- Dealt coins land on top of whatever is there, matching or not. After a deal the same resolution runs: fuse, seal, thaw, reveal.
- **The solver treats a deal as one more action.** The state key includes the deal index.
  - `clearBoard` is met only when the board is empty *and* the queue is exhausted.
  - `blocked` means no legal move *and* no legal deal.
- Undo and restart restore the deal index exactly.
- **Preview:** the deal button shows the number of batches left and mini-coins for the next batch.
- **Rollout:** introduced at level 3 with a one-time explainer. Later chapters combine it with forge, veiled and frost.

### 2.2 Visual model: 3D disc stacks (replaces face-on overlapping coins)

- Each coin is a thick disc seen from about 55° above:
  - an elliptical top face (height 0.55·d) carrying the enamel, glyph and rim pattern;
  - a cylindrical edge band (thickness 0.16·d) with a **family-specific edge texture** (reeded / dotted / chevron …) and the family colour.
- Stacks grow **upward**: the top coin's face is fully visible and lower coins show their edge bands. This differs from the reference, whose stacks grow toward the viewer.
- Tier ≥ 2 gets a brass edge and tier pips on the face. Veiled coins have a neutral pewter edge so they leak no information. Frosted coins get an ice-glazed edge and an ice cap on the face; a counter badge sits beside the tray at that coin's height.
- Tray capacity can now reach ~10 compactly, giving the big, satisfying stacks.

### 2.3 Motion spec (≤ budget in design.md §4; halved with no particles under reduced motion)

| Event | Ours |
|---|---|
| Select | Run lifts 0.55·faceH in 110 ms (easeOutCubic), then a gentle 1.5 px idle bob |
| Move | Per coin: 210 ms arc, 38 ms stagger, tumble (face squashes to edge-on and back, 1 flip) plus a slight z-rotation; landing squash 1.0→0.92→1.0 over 90 ms; one "clink" per coin with ±3 semitone pitch variation |
| Full | Tray gets a jade outline glow, then 150 ms hold |
| Fuse | Bottom→top white sweep (160 ms) → compress toward the base (200 ms) → burst: radial glow + expanding ring + 10–16 star sparkles (300 ms) → new coin pops 0→1.18→1 (260 ms, easeOutBack) |
| Seal / goal | Sealed coins fly to their HUD goal tile along a curved path (380 ms, staggered 60 ms); the tile pops 1→1.15→1 and its counter ticks |
| Chain | "Chain ×N!": letters type in at 45 ms each with a wave offset, hold 500 ms, then fade out letter by letter |
| Deal | Coins launch from the deal button in a fan, tumble, and land staggered across trays (≈650 ms per batch) |
| Modals | 0.6 → 1.06 → 1.0, 260 ms, with backdrop fade |

### 2.4 HUD: goal tiles

- `clearBoard`: one tile per family in play, showing the sets still to seal. The tile receives that family's seal flights.
- `forge{tier, count}`: one tile showing that coin tier and the count remaining.

### 2.5 Audio additions (synthesised, original)

Pitch-varied clink ×3, whoosh, burst/sparkle, chain stinger and deal shuffle.

## 3. Out of scope

- Lives/hearts and timed paid slots. They conflict with design.md §9 and the product pillars.
- True 3D meshes. The 2.5D disc renderer is enough; the true-3D spike is still deferred.

## 4. Risks

- **Solver state space grows with deals.** Mitigation: keep the deal index in the key, use the heuristic search with a budget, and have the offline generator reject levels that blow the budget.
- **Taller stacks need tap targets on small phones.** The layout still guarantees ≥ 48 dp per tray column.
