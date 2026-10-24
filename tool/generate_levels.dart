// Generates the bundled campaign pack: authored tutorial + seeded, solver
// verified levels. Deterministic: same code + same plan = same pack.
//
//   dart run tool/generate_levels.dart
//
// Writes assets/levels/campaign.json and prints a difficulty report.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'dart:isolate';

import 'package:coin/domain/generator/level_generator.dart';
import 'package:coin/domain/model/board.dart';
import 'package:coin/domain/model/coin.dart';
import 'package:coin/domain/model/level.dart';
import 'package:coin/domain/model/move.dart';
import 'package:coin/domain/model/objective.dart';
import 'package:coin/domain/rules/level_validator.dart';
import 'package:coin/domain/rules/rules_engine.dart';
import 'package:coin/domain/solver/solver.dart';

const engine = RulesEngine();
const solver = Solver();
const generator = LevelGenerator();
const validator = LevelValidator();
const packVersion = 5;

/// One planned level: spec + difficulty band (solver nodes / solution length).
class Plan {
  const Plan(
    this.chapter,
    this.spec, {
    required this.difficulty,
    this.minNodes = 0,
    this.maxNodes = 1 << 30,
    this.minLength = 1,
    this.introduces,
    this.budget = 400000,
  });

  final int chapter;
  final GeneratorSpec spec;
  final String difficulty;
  final int minNodes;
  final int maxNodes;
  final int minLength;
  final String? introduces;

  /// Solver node budget. Big boards cost far more per node, so they only
  /// accept seeds the solver clears quickly.
  final int budget;
}

GeneratorSpec s({
  required int f,
  int k = 3,
  int tier = 1,
  required int cap,
  required int stacks,
  int empty = 1,
  int high = 0,
  double hidden = 0,
  int frost = 0,
  int frostLevel = 1,
  int sets = 1,
  int deals = 0,
  int dealSize = 0,
  ObjectiveDefinition objective = const ClearBoardObjective(),
  bool fill = false,
  int extra = 0,
}) => GeneratorSpec(
  extraSetFamilies: extra,
  // Fill mode: every tray is [cap] high and a set is a full tray, so sets
  // are converted from k-sized to cap-sized.
  fillCapacities: fill ? [cap] : const [],
  deals: deals,
  dealSize: dealSize,
  families: f,
  mergeThreshold: k,
  maxTier: tier,
  capacity: cap,
  stacks: stacks,
  emptyStacks: empty,
  higherTierCoins: high,
  hiddenRatio: hidden,
  frostCount: frost,
  frostLevel: frostLevel,
  setsPerFamily: fill ? math.max(1, (k * sets / cap).round()) : sets,
  objective: objective,
);

/// Chapters 1–4: short, one mechanic each (unchanged since pack v3).
final introPlans = <Plan>[
  // Chapter 1 — First Light: sort, seal, and (from level 3) deal.
  Plan(
    1,
    s(f: 2, cap: 4, stacks: 4, fill: true),
    difficulty: 'easy',
    minLength: 3,
    introduces: 'fill',
  ),
  Plan(
    1,
    s(f: 3, cap: 5, stacks: 4, deals: 2, dealSize: 3, fill: true),
    difficulty: 'easy',
    minLength: 5,
    introduces: 'deal',
  ),
  Plan(
    1,
    s(f: 3, k: 4, cap: 6, stacks: 4, deals: 2, dealSize: 4, fill: true),
    difficulty: 'easy',
    minNodes: 8,
    minLength: 6,
  ),
  Plan(
    1,
    s(f: 4, k: 4, cap: 6, stacks: 5, deals: 3, dealSize: 4, fill: true),
    difficulty: 'medium',
    minNodes: 15,
    minLength: 8,
  ),
  Plan(
    1,
    s(f: 3, k: 5, cap: 7, stacks: 4, deals: 3, dealSize: 4, fill: true),
    difficulty: 'medium',
    minNodes: 15,
    minLength: 8,
  ),
  Plan(
    1,
    s(
      f: 4,
      k: 4,
      cap: 7,
      stacks: 5,
      sets: 2,
      deals: 4,
      dealSize: 4,
      fill: true,
    ),
    difficulty: 'medium',
    minNodes: 25,
    minLength: 12,
  ),
  Plan(
    1,
    s(
      f: 4,
      k: 4,
      cap: 8,
      stacks: 6,
      sets: 2,
      deals: 4,
      dealSize: 4,
      fill: true,
    ),
    difficulty: 'hard',
    minNodes: 30,
    minLength: 12,
  ),
  Plan(
    1,
    s(
      f: 3,
      k: 5,
      cap: 8,
      stacks: 5,
      sets: 2,
      deals: 4,
      dealSize: 5,
      fill: true,
    ),
    difficulty: 'hard',
    minNodes: 30,
    minLength: 12,
  ),
  Plan(
    1,
    s(
      f: 4,
      k: 5,
      cap: 9,
      stacks: 6,
      sets: 2,
      deals: 5,
      dealSize: 5,
      fill: true,
    ),
    difficulty: 'hard',
    minNodes: 40,
    minLength: 14,
  ),
  // Chapter 2 — The Forge: three alike fuse up a tier.
  Plan(
    2,
    s(f: 2, tier: 2, cap: 6, stacks: 4, high: 2),
    difficulty: 'easy',
    minLength: 4,
    introduces: 'forge',
  ),
  Plan(
    2,
    s(f: 3, tier: 2, cap: 6, stacks: 5, high: 1, deals: 2, dealSize: 3),
    difficulty: 'easy',
    minNodes: 8,
    minLength: 6,
  ),
  Plan(
    2,
    s(
      f: 3,
      tier: 2,
      cap: 6,
      stacks: 5,
      high: 2,
      deals: 2,
      dealSize: 3,
      objective: const ForgeObjective(tier: 2, count: 3),
    ),
    difficulty: 'easy',
    minLength: 4,
  ),
  Plan(
    2,
    s(f: 3, tier: 2, cap: 7, stacks: 5, high: 1, deals: 3, dealSize: 4),
    difficulty: 'medium',
    minNodes: 20,
    minLength: 10,
  ),
  Plan(
    2,
    s(f: 4, tier: 2, cap: 7, stacks: 6, high: 2, deals: 3, dealSize: 4),
    difficulty: 'medium',
    minNodes: 25,
    minLength: 10,
  ),
  Plan(
    2,
    s(
      f: 4,
      tier: 2,
      cap: 7,
      stacks: 6,
      high: 1,
      deals: 3,
      dealSize: 4,
      objective: const ForgeObjective(tier: 2, count: 6),
    ),
    difficulty: 'medium',
    minNodes: 15,
    minLength: 8,
  ),
  Plan(
    2,
    s(f: 4, tier: 2, cap: 8, stacks: 6, high: 1, deals: 4, dealSize: 4),
    difficulty: 'hard',
    minNodes: 40,
    minLength: 14,
  ),
  Plan(
    2,
    s(f: 5, tier: 2, cap: 8, stacks: 7, high: 2, deals: 4, dealSize: 4),
    difficulty: 'hard',
    minNodes: 40,
    minLength: 14,
  ),
  Plan(
    2,
    s(f: 5, tier: 2, cap: 8, stacks: 7, high: 1, deals: 4, dealSize: 5),
    difficulty: 'hard',
    minNodes: 50,
    minLength: 16,
  ),
  Plan(
    2,
    s(
      f: 5,
      tier: 2,
      cap: 9,
      stacks: 7,
      high: 1,
      empty: 2,
      deals: 5,
      dealSize: 5,
    ),
    difficulty: 'expert',
    minNodes: 60,
    minLength: 18,
  ),
  // Chapter 3 — Veiled Vault: hidden coins.
  Plan(
    3,
    s(f: 3, cap: 5, stacks: 6, hidden: 0.5, fill: true),
    difficulty: 'easy',
    minLength: 5,
    introduces: 'hidden',
  ),
  Plan(
    3,
    s(f: 4, cap: 6, stacks: 5, hidden: 0.5, deals: 2, dealSize: 4, fill: true),
    difficulty: 'easy',
    minNodes: 10,
    minLength: 7,
  ),
  Plan(
    3,
    s(
      f: 4,
      k: 4,
      cap: 7,
      stacks: 5,
      hidden: 0.5,
      deals: 3,
      dealSize: 4,
      fill: true,
    ),
    difficulty: 'medium',
    minNodes: 20,
    minLength: 10,
  ),
  Plan(
    3,
    s(
      f: 3,
      tier: 2,
      cap: 7,
      stacks: 5,
      high: 2,
      hidden: 0.4,
      deals: 2,
      dealSize: 4,
    ),
    difficulty: 'medium',
    minNodes: 20,
    minLength: 10,
  ),
  Plan(
    3,
    s(f: 5, cap: 6, stacks: 6, hidden: 0.6, deals: 3, dealSize: 4, fill: true),
    difficulty: 'medium',
    minNodes: 25,
    minLength: 11,
  ),
  Plan(
    3,
    s(
      f: 5,
      k: 4,
      cap: 7,
      stacks: 6,
      hidden: 0.5,
      deals: 4,
      dealSize: 4,
      fill: true,
    ),
    difficulty: 'hard',
    minNodes: 35,
    minLength: 12,
  ),
  Plan(
    3,
    s(
      f: 4,
      tier: 2,
      cap: 8,
      stacks: 6,
      high: 2,
      hidden: 0.5,
      deals: 3,
      dealSize: 4,
    ),
    difficulty: 'hard',
    minNodes: 35,
    minLength: 12,
  ),
  Plan(
    3,
    s(f: 6, cap: 6, stacks: 7, hidden: 0.6, deals: 4, dealSize: 5, fill: true),
    difficulty: 'hard',
    minNodes: 40,
    minLength: 13,
  ),
  Plan(
    3,
    s(
      f: 6,
      k: 4,
      cap: 8,
      stacks: 7,
      hidden: 0.6,
      deals: 4,
      dealSize: 5,
      fill: true,
    ),
    difficulty: 'hard',
    minNodes: 50,
    minLength: 14,
  ),
  Plan(
    3,
    s(
      f: 5,
      tier: 2,
      cap: 8,
      stacks: 7,
      high: 2,
      hidden: 0.5,
      deals: 4,
      dealSize: 5,
    ),
    difficulty: 'expert',
    minNodes: 60,
    minLength: 16,
  ),
  // Chapter 4 — Frostworks: frost seals.
  Plan(
    4,
    s(f: 3, cap: 5, stacks: 5, frost: 1, fill: true),
    difficulty: 'easy',
    minLength: 5,
    introduces: 'frost',
  ),
  Plan(
    4,
    s(f: 3, cap: 6, stacks: 5, frost: 2, deals: 2, dealSize: 3, fill: true),
    difficulty: 'easy',
    minNodes: 10,
    minLength: 7,
  ),
  Plan(
    4,
    s(f: 4, cap: 6, stacks: 6, frost: 2, deals: 3, dealSize: 4, fill: true),
    difficulty: 'medium',
    minNodes: 20,
    minLength: 9,
  ),
  Plan(
    4,
    s(
      f: 4,
      k: 4,
      cap: 7,
      stacks: 6,
      frost: 2,
      deals: 3,
      dealSize: 4,
      fill: true,
    ),
    difficulty: 'medium',
    minNodes: 25,
    minLength: 10,
  ),
  Plan(
    4,
    s(
      f: 4,
      cap: 6,
      stacks: 6,
      frost: 2,
      frostLevel: 2,
      deals: 3,
      dealSize: 4,
      fill: true,
    ),
    difficulty: 'medium',
    minNodes: 25,
    minLength: 10,
  ),
  Plan(
    4,
    s(
      f: 3,
      tier: 2,
      cap: 7,
      stacks: 6,
      high: 2,
      frost: 2,
      deals: 3,
      dealSize: 4,
    ),
    difficulty: 'hard',
    minNodes: 35,
    minLength: 11,
  ),
  Plan(
    4,
    s(f: 5, cap: 6, stacks: 7, frost: 3, deals: 4, dealSize: 4, fill: true),
    difficulty: 'hard',
    minNodes: 40,
    minLength: 12,
  ),
  Plan(
    4,
    s(
      f: 5,
      cap: 7,
      stacks: 7,
      frost: 2,
      hidden: 0.3,
      deals: 4,
      dealSize: 4,
      fill: true,
    ),
    difficulty: 'hard',
    minNodes: 45,
    minLength: 13,
  ),
  Plan(
    4,
    s(
      f: 5,
      k: 4,
      cap: 8,
      stacks: 7,
      frost: 3,
      hidden: 0.3,
      deals: 4,
      dealSize: 5,
      fill: true,
    ),
    difficulty: 'expert',
    minNodes: 55,
    minLength: 14,
  ),
  Plan(
    4,
    s(
      f: 5,
      tier: 2,
      cap: 8,
      stacks: 7,
      high: 2,
      frost: 2,
      frostLevel: 2,
      deals: 4,
      dealSize: 5,
    ),
    difficulty: 'expert',
    minNodes: 60,
    minLength: 16,
  ),
];

LevelDefinition tutorial() {
  CoinState c(String id, String f) => CoinState(id: id, familyId: f);
  final board = BoardState(
    rules: const RuleSet(mergeThreshold: 3, maxTier: 1, fillToSeal: true),
    stacks: [
      StackState(
        id: 's0',
        capacity: 3,
        coins: [c('c0', 'jade'), c('c1', 'ruby'), c('c2', 'ruby')],
      ),
      StackState(
        id: 's1',
        capacity: 3,
        coins: [c('c3', 'ruby'), c('c4', 'jade'), c('c5', 'jade')],
      ),
      StackState(id: 's2', capacity: 3, coins: const []),
    ],
  );
  const steps = [
    TutorialStep(messageKey: 'tutorialMove', move: MoveCommand('s0', 's2')),
    TutorialStep(messageKey: 'tutorialUndo', expectUndo: true),
    TutorialStep(messageKey: 'tutorialRedo', move: MoveCommand('s0', 's2')),
    TutorialStep(messageKey: 'tutorialFuse', move: MoveCommand('s1', 's0')),
    TutorialStep(messageKey: 'tutorialFinish', move: MoveCommand('s1', 's2')),
  ];
  // The proof path is what remains after the scripted undo.
  final path = <MoveCommand>[];
  for (final st in steps) {
    if (st.expectUndo) {
      path.removeLast();
    } else if (st.move != null) {
      path.add(st.move!);
    }
  }
  return finish(
    id: 'c1-01',
    number: 1,
    chapter: 1,
    difficulty: 'tutorial',
    board: board,
    objective: const ClearBoardObjective(),
    reward: 25,
    path: path,
    nodes: 0,
    tutorial: steps,
    introduces: 'basics',
  );
}

LevelDefinition finish({
  required String id,
  required int number,
  required int chapter,
  required String difficulty,
  required BoardState board,
  required ObjectiveDefinition objective,
  required int reward,
  required List<MoveCommand> path,
  required int nodes,
  int? seed,
  List<TutorialStep> tutorial = const [],
  String? introduces,
}) => LevelDefinition(
  id: id,
  number: number,
  chapter: chapter,
  version: packVersion,
  difficulty: difficulty,
  initialState: board,
  objective: objective,
  reward: reward,
  parMoves: path.length,
  seed: seed,
  generatorVersion: seed == null ? null : LevelGenerator.version,
  tutorial: tutorial,
  introduces: introduces,
  proof: SolverProof(
    solution: path,
    solutionHash: Solver.hashPath(path),
    nodesExpanded: nodes,
    solverVersion: Solver.version,
  ),
);

/// Mechanics a long chapter mixes in. Board size does not come from here:
/// it follows the campaign-wide curve in [levelPlan].
class ChapterFlavor {
  const ChapterFlavor({
    this.hidden = false,
    this.frost = false,
    this.forge = false,
  });

  final bool hidden, frost;

  /// Two-tier coins (fuse three alike up a tier, then seal).
  final bool forge;
}

/// Chapters 5–17. Each new mechanic is introduced on its own, then mixed
/// with the others.
const flavors = <int, ChapterFlavor>{
  5: ChapterFlavor(),
  6: ChapterFlavor(),
  7: ChapterFlavor(forge: true),
  8: ChapterFlavor(hidden: true),
  9: ChapterFlavor(frost: true),
  10: ChapterFlavor(),
  11: ChapterFlavor(hidden: true, frost: true),
  12: ChapterFlavor(forge: true, hidden: true),
  13: ChapterFlavor(forge: true, frost: true),
  14: ChapterFlavor(hidden: true),
  15: ChapterFlavor(frost: true, hidden: true),
  16: ChapterFlavor(forge: true, hidden: true, frost: true),
  17: ChapterFlavor(hidden: true, frost: true),
};

/// First level number after the four teaching chapters.
const firstLong = 41;
const lastLevel = 300;

/// Plan for level [n] (41–300). Everything that makes a board bigger grows
/// steadily with n, so each level is a little larger than the one before:
/// coin types 4→8, coins ~30→150, trays 7→16, tray height 7→12, seal size
/// 3→5, deals 2→6. On top of that, every 5th level is "hard" and every
/// 10th "super hard": same size class, but only seeds whose solution takes
/// real search are accepted.
Plan levelPlan(int n) => longPlans[n - firstLong];

/// Built in order so size never shrinks from one level to the next.
final longPlans = () {
  final out = <Plan>[];
  var prevCoins = 0, prevStacks = 0, prevCap = 0;
  for (var n = firstLong; n <= lastLevel; n++) {
    final (plan, coins) = _plan(n, prevCoins, prevStacks, prevCap);
    out.add(plan);
    prevCoins = coins;
    prevStacks = plan.spec.stacks;
    prevCap = plan.spec.capacity;
  }
  return out;
}();

(Plan, int) _plan(int n, int prevCoins, int prevStacks, int prevCap) {
  final p = (n - firstLong) / (lastLevel - firstLong); // 0..1
  final chapter = 5 + (n - firstLong) ~/ 20;
  final flavor = flavors[chapter]!;
  final pos = (n - firstLong) % 20;
  final difficulty = pos == 9 || pos == 19
      ? 'expert'
      : pos % 5 == 4
      ? 'hard'
      : pos < 2
      ? 'easy'
      : 'medium';

  final f = (4 + 4.99 * p).floor().clamp(4, 8);
  // Two-tier (forge) boards fuse three alike; every other chapter plays
  // fill mode, where a set is a whole tray: 5 to 12 coins.
  final tier = flavor.forge ? 2 : 1;
  final fill = !flavor.forge;
  final cap = math.max(prevCap, (7 + 5 * p).round().clamp(5, 12));
  final k = tier == 2 ? 3 : (p < 0.55 ? 4 : 5);
  final high = tier == 2 ? 1 : 0;
  final perSet = tier == 2 ? high + (k - high) * k : (fill ? cap : k);
  final hard = difficulty == 'hard' || difficulty == 'expert';
  // Drops spray several coins over several trays; bigger in fill mode.
  final deals = (2 + 5 * p).round() + (hard ? 1 : 0);
  final dealSize = fill ? (5 + 3 * p).round() : (4 + 2 * p).round();
  final int coins, stacks;
  var extra = 0;
  if (fill) {
    // Fill boards start sparse, like the reference: a third to a half of
    // the room is taken and the rest of the coins arrive by drop. The
    // squeeze comes from set sizes that grow with the trays.
    stacks = math.max(prevStacks, (7 + 9 * p).round()).clamp(4, 16);
    final room = stacks * cap;
    final onBoard = room * (0.34 + 0.14 * p + (hard ? 0.05 : 0));
    final target = onBoard + deals * dealSize;
    // Whole sets, spread so the total lands near the target.
    var total = math.max(f, (target / perSet).round());
    if (total * perSet < prevCoins * 0.8) total++;
    extra = total % f;
    coins = total * perSet;
  } else {
    // Target coin count rises smoothly from ~30 to ~150. Sets come in whole
    // chunks (f * perSet coins), so aim for the target and allow small
    // dips; trays and tray height never shrink.
    final target = 30 + 120 * p;
    var sets = math.max(1, (target / (f * perSet)).round());
    if (f * sets * perSet < prevCoins * 0.85) sets++;
    // Never more than 14 working trays can hold at 72% full.
    while (sets > 1 &&
        f * (sets - 1) * perSet >= target * 0.8 &&
        f * sets * perSet * 0.6 > 14 * cap * 0.72) {
      sets--;
    }
    coins = f * sets * perSet;
    // Coins left on the board after deals take their share (at most half).
    final onBoard = coins - (deals * dealSize).clamp(0, coins ~/ 2);
    final needed = (onBoard / (cap * 0.72)).ceil() + 2;
    stacks = math
        .max(prevStacks, math.max((7 + 9 * p).round(), needed))
        .clamp(4, 16);
  }
  final sets = (coins ~/ perSet - extra) ~/ f;
  final hidden = flavor.hidden
      // Capped near half: beyond that stacks read as walls of grey.
      ? (0.25 + 0.2 * p + (hard ? 0.08 : 0)).clamp(0.0, 0.5)
      : 0.0;
  // Frost thaws on nearby seals. In fill mode a seal needs a whole tray, so
  // frost stays light there: few coins, single level.
  final frost = !flavor.frost
      ? 0
      : fill
      ? (1 + (1.5 * p).round() + (hard ? 1 : 0)).clamp(1, 3)
      : 1 + (3 * p).round() + (hard ? 1 : 0);
  // Search-hardness is only affordable on small boards: a node of a big
  // board with deals costs ~1 ms, so a seed the solver cannot finish costs
  // seconds. Big boards are made hard by content instead (more deals,
  // veils and frost, longer solutions) and must be solved quickly.
  final small = coins <= 40;
  final (minNodes, minLength, budget) = switch (difficulty) {
    'easy' => (small ? 5 : 0, 8, small ? 40000 : 2500),
    'medium' => (small ? 15 : 0, 10, small ? 60000 : 2500),
    'hard' => (small ? 40 : 0, 14, small ? 80000 : 3000),
    _ => (small ? 60 : 0, 18, small ? 100000 : 3500),
  };
  final plan = Plan(
    chapter,
    s(
      f: f,
      // s() resizes fill sets from k-sized; sets here are already tray-sized.
      k: fill ? cap : k,
      tier: tier,
      high: high,
      cap: cap,
      stacks: stacks,
      empty: 2,
      sets: sets,
      hidden: hidden,
      frost: frost,
      frostLevel: !fill && p > 0.3 ? 2 : 1,
      deals: deals,
      dealSize: dealSize,
      fill: fill,
      extra: extra,
      // Every 5th level of a forge chapter asks for forged coins.
      objective: tier == 2 && pos % 5 == 2
          ? ForgeObjective(tier: 2, count: f)
          : const ClearBoardObjective(),
    ),
    difficulty: difficulty,
    minNodes: minNodes,
    minLength: minLength + (20 * p).round(),
    budget: budget,
  );
  return (plan, coins);
}

/// Gilt for a level: grows slowly with the chapter; hard levels pay more.
int rewardFor(int chapter, String difficulty) {
  if (chapter <= 4) return 10 + chapter * 5;
  final base = 30 + chapter;
  final mult = switch (difficulty) {
    'hard' => 1.5,
    'expert' => 2.0,
    _ => 1.0,
  };
  return ((base * mult) / 5).round() * 5;
}

final plans = [
  ...introPlans,
  for (var n = firstLong; n <= lastLevel; n++) levelPlan(n),
];

/// Generates one level. Pure function of (plan, number, id): safe to run
/// on any isolate, so the pack stays deterministic.
(LevelDefinition?, String) generateOne(Plan plan, int number, String id) {
  LevelDefinition? chosen;
  var line = '';
  // Search seeds deterministically; relax the band if nothing fits.
  for (var relax = 0; relax < 4 && chosen == null; relax++) {
    final minNodes = plan.minNodes >> relax;
    final minLength = plan.minLength - relax;
    // Long chapters relax sooner: a failed seed on a big board is costly.
    final attempts = plan.chapter <= 4 ? 3000 : 500;
    for (var attempt = 0; attempt < attempts; attempt++) {
      final seed = number * 100000 + relax * 10000 + attempt;
      final raw = generator.candidate(plan.spec, seed);
      if (raw == null) continue;
      final b = engine.settle(raw);
      if (engine.invariantViolations(b).isNotEmpty) continue;
      if (plan.spec.objective.isMet(b)) continue;
      final r = solver.solve(b, plan.spec.objective, maxNodes: plan.budget);
      if (!r.isSolved) continue;
      if (r.nodesExpanded < minNodes || r.nodesExpanded > plan.maxNodes) {
        continue;
      }
      if (r.path.length < minLength) continue;
      // Forgiving deals: pressing Deal first must never doom the level.
      if (engine.validateDeal(b).isLegal &&
          !solver
              .solve(
                engine.apply(b, MoveCommand.deal, recordEvents: false).next,
                plan.spec.objective,
                maxNodes: plan.budget,
              )
              .isSolved) {
        continue;
      }
      chosen = finish(
        id: id,
        number: number,
        chapter: plan.chapter,
        difficulty: plan.difficulty,
        board: raw,
        objective: plan.spec.objective,
        reward: rewardFor(plan.chapter, plan.difficulty),
        path: r.path,
        nodes: r.nodesExpanded,
        seed: seed,
        introduces: plan.introduces,
      );
      line =
          ('${id.padRight(6)} ${plan.difficulty.padRight(8)} '
          '${seed.toString().padLeft(7)} ${r.nodesExpanded.toString().padLeft(6)} '
          '${r.path.length.toString().padLeft(4)}  ${b.coinCount}'
          '${relax > 0 ? '  (relaxed x$relax)' : ''}');
      break;
    }
  }
  if (chosen == null) return (null, 'FAILED to generate $id');
  final issues = validator.validate(chosen);
  if (issues.isNotEmpty) return (null, '$id invalid: $issues');
  return (chosen, line);
}

Future<void> main(List<String> args) async {
  if (args.contains('--plan')) {
    // Prints the growth curve without generating anything.
    for (var n = firstLong; n <= lastLevel; n++) {
      final sp = levelPlan(n).spec;
      final setsTotal = sp.families * sp.setsPerFamily + sp.extraSetFamilies;
      final per = sp.maxTier == 2
          ? 1 + (sp.mergeThreshold - 1) * 3
          : sp.mergeThreshold;
      stdout.writeln(
        '$n ${levelPlan(n).difficulty.padRight(7)} f${sp.families} '
        'k${sp.mergeThreshold} t${sp.maxTier} coins ${setsTotal * per} '
        'trays ${sp.stacks} cap ${sp.capacity} deals ${sp.deals}x${sp.dealSize} '
        'hid ${sp.hiddenRatio.toStringAsFixed(2)} frost ${sp.frostCount}',
      );
    }
    return;
  }
  final levels = <LevelDefinition>[tutorial()];
  final report = StringBuffer('level  diff     seed   nodes  len  coins\n');
  // Ids and numbers are fixed up front; generation then fans out.
  final jobs = <(Plan, int, String)>[];
  final perChapter = <int, int>{1: 1};
  for (final (i, plan) in plans.indexed) {
    final n = (perChapter[plan.chapter] ?? 0) + 1;
    perChapter[plan.chapter] = n;
    jobs.add((plan, i + 2, 'c${plan.chapter}-${n.toString().padLeft(2, '0')}'));
  }
  final results = List<(LevelDefinition?, String)?>.filled(jobs.length, null);
  var next = 0;
  final sw = Stopwatch()..start();
  Future<void> worker() async {
    while (next < jobs.length) {
      final j = next++;
      final (plan, number, id) = jobs[j];
      results[j] = await Isolate.run(() => generateOne(plan, number, id));
      stdout.writeln('${results[j]!.$2}   [${sw.elapsed.inSeconds}s]');
    }
  }

  await Future.wait([
    for (var w = 0; w < Platform.numberOfProcessors; w++) worker(),
  ]);
  for (final r in results) {
    final (level, line) = r!;
    if (level == null) {
      stderr.writeln(line);
      exitCode = 1;
      return;
    }
    levels.add(level);
    report.writeln(line);
  }

  final tut = levels.first;
  final tutIssues = validator.validate(tut);
  if (tutIssues.isNotEmpty) {
    stderr.writeln('tutorial invalid: $tutIssues');
    exitCode = 1;
    return;
  }

  final pack = {
    'packVersion': packVersion,
    'rulesVersion': BoardState.rulesVersion,
    'solverVersion': Solver.version,
    'generatorVersion': LevelGenerator.version,
    'levels': [for (final l in levels) l.toJson()],
  };
  // Compact: 300 levels with big boards would be several MB indented.
  File('assets/levels/campaign.json').writeAsStringSync(jsonEncode(pack));
  stdout
    ..write(report)
    ..writeln('Wrote ${levels.length} levels.');
}
