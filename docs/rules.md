# Coin Atelier — Canonical Rules (rules version 2)

The rules are implemented in exactly one place, `lib/domain/rules/rules_engine.dart`.
Gameplay, hints, blocked-board detection, the solver and every level tool call it.
If this document and the code ever disagree, the code is wrong and needs a fix plus a regression test.

## Board

- A board is an ordered list of **trays** (stacks). Each tray has a capacity.
- Within a tray, index 0 is the **bottom** coin and the last coin is the **top**.
- A coin's identity for matching is **(family, tier)**.
- Each level also sets a **merge threshold K** (how many alike coins fuse) and a **max tier M**.

## Moves

A move is `MoveCommand(from, to)`. The UI never decides how many coins move.

1. The **top run** of a tray is the contiguous run of identical, *active* coins at its top.
   A coin is active when it is revealed and not frozen.
2. A move is legal only when:
   - both trays exist and are different;
   - the source has an active top coin;
   - the destination has free space;
   - the destination is empty, **or** its top coin is the same kind and not frozen.
3. Coins move one at a time. Movement stops at whichever comes first:
   - the source run runs out;
   - the destination is full;
   - the destination's top run reaches K.
   So `count = min(sourceRun, freeSpace, K − destinationRun)`, where an empty destination counts as a run of 0.
4. Illegal moves change nothing: no board change, no move count, no currency, no RNG.

## Fusing and sealing (resolution)

After the coins land, the engine **resolves**, repeating until nothing changes (with a hard cap of 256 steps; going over the cap is a defect, not a player error):

1. Reveal the top coin of every tray.
2. Find the first tray whose top run is K or more. The destination tray is checked first, then the rest in board order.
3. Remove its top K coins. Then:
   - **tier < M**: put one coin of the same family at tier + 1 on top. It gets the deterministic id `f<serial>`, and `forged[tier+1]` goes up by 1.
   - **tier = M**: the set is **sealed** (it leaves the board) and `sealed` goes up by 1.
4. Each fuse or seal thaws frosted coins in that tray and in both neighbouring trays (index ± 1) by 1.

Resolution is deterministic: the same state and move always produce the same result and the same event log.

## Special coins

| Type | Rule | Solver | Undo |
|---|---|---|---|
| **Veiled** (`hidden`) | Identity is hidden until the coin becomes a tray's top coin. It stays revealed after that. A veiled coin is not active, so it never joins a run. | The solver sees true identities. Every level is still proven solvable, so luck never matters. | `isRevealed` is part of the board state and is restored exactly. |
| **Frost** (`frosted`) | A coin with `frost > 0` cannot be lifted, matched or covered. Each fuse in its tray or a neighbouring tray lowers `frost` by 1. At 0 it becomes a normal coin. | Frost level is part of the state key. Symmetry reduction is turned off while frost exists, because tray position matters. | The frost level is restored exactly. |

State diagrams:

```
Veiled:  hidden ──(becomes top coin)──▶ revealed   (terminal)
Frost:   frost=n ──(fuse in own/adjacent tray)──▶ frost=n-1 … ──▶ frost=0 (normal coin)
```

## Deals (rules v2)

- A level can carry a fixed, ordered **deal queue**. Each batch says exactly which coins land on which tray. The coin ids are in the level data, so nothing is random.
- `Deal` is an action handled by the same pipeline as moves (`MoveCommand.deal`). It is legal only when a batch remains **and** every tray that batch targets has room for its coins.
  - If a tray lacks room, the move is rejected with `dealNoRoom` and the blocking trays are highlighted.
- Dealt coins land on top of whatever is there, matching or not. Resolution then runs exactly as after a move.
- `clearBoard` also requires the queue to be empty.
- The solver includes `dealIndex` in its state key and treats Deal as one more action. Symmetry reduction is off for levels with deals.
- The generator also requires that pressing Deal first never makes the level unwinnable.

## Workshop slots and the bonus tray (extra trays)

- **Workshop slots:** five permanent top-row slots (ids `w0`–`w4`). They unlock in order with earned gilt once the player has completed enough levels (see `WorkshopCatalog`).
  - An unlocked slot is an empty tray, up to 6 deep and never shallower than the fuse count, added to every level except the tutorial.
- **Unlocking mid-level:** the new tray is also added to every undo snapshot, so undo and restart keep the upgrade.
- **The bonus tray** (booster) and workshop trays are *auxiliary*:
  - They never count as frost neighbours.
  - A fuse inside them thaws nothing else.
  - Because they only add options, every proven-solvable level stays solvable.

## Objectives

- `clearBoard`: no coins left. The validator checks that every family's total value in tier-1 units divides exactly into K^M.
- `forge{tier, count}`: forge `count` coins of `tier`. Coins of that tier present at the start do not count.

## Board status

- `completed`: the objective is met. This is terminal; every command is rejected.
- `noLegalMoves`: `legalMoves(state)` is empty. Only this authoritative check can show the "No moves left" screen.
- `deadEnd` (advisory): the solver **proved** (`unsolvedProven`) that no solution exists from here. A banner suggests Undo or Restart.
  A budget timeout (`unknownBudgetExceeded`) is **never** treated as impossible.

## Undo, restart, booster

- **Undo** restores the exact previous `BoardState`: coins, frost, reveals, objective progress, move count and serial. It is free and unlimited up to 200 steps (the last 30 are persisted).
- **Restart** restores the exact initial board.
- The **extra tray** booster adds an empty bonus tray and clears undo history. This means undo can never undo a booster's effect while it stays spent. The booster is spent only after the tray has been added.
- **Hint** runs the solver off the UI isolate. It is charged only when a move is found and the board has not changed since the request.
