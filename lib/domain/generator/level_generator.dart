import 'dart:math' as math;

import '../../core/seeded_random.dart';
import '../model/board.dart';
import '../model/coin.dart';
import '../model/families.dart';
import '../model/objective.dart';

/// Parameters for one generated board.
final class GeneratorSpec {
  const GeneratorSpec({
    required this.families,
    required this.mergeThreshold,
    required this.maxTier,
    required this.capacity,
    required this.stacks,
    required this.emptyStacks,
    this.setsPerFamily = 1,
    this.higherTierCoins = 0,
    this.hiddenRatio = 0,
    this.frostCount = 0,
    this.frostLevel = 1,
    this.objective = const ClearBoardObjective(),
    this.deals = 0,
    this.dealSize = 0,
    this.fillCapacities = const [],
    this.extraSetFamilies = 0,
  });

  final int families;
  final int mergeThreshold;
  final int maxTier;
  final int capacity;
  final int stacks;
  final int emptyStacks;
  final int setsPerFamily;

  /// For maxTier >= 2: how many tier-2 coins per family replace their
  /// tier-1 equivalents (adds variety without changing totals).
  final int higherTierCoins;
  final double hiddenRatio;
  final int frostCount;
  final int frostLevel;
  final ObjectiveDefinition objective;

  /// Number of deal batches and coins per batch (taken from the coin pool).
  final int deals;
  final int dealSize;

  /// Non-empty selects fill mode: tray heights are drawn from this list
  /// (cycled over the trays, then shuffled) and each family's set size is
  /// one of them. [capacity] is then the tallest tray allowed.
  final List<int> fillCapacities;

  bool get fill => fillCapacities.isNotEmpty;

  /// The first this many families get one set more than [setsPerFamily],
  /// so the coin total can land near a target instead of jumping by a whole
  /// round of sets.
  final int extraSetFamilies;
}

/// Deterministic candidate generator. It does NOT guarantee solvability; the
/// offline pipeline runs every candidate through the solver and rejects
/// failures (architecture.md §7, generator policy).
final class LevelGenerator {
  const LevelGenerator();

  static const int version = 2;

  /// Returns null when the seed yields a structurally unusable layout.
  BoardState? candidate(GeneratorSpec spec, int seed) {
    final rng = SeededRandom(seed);
    final k = spec.mergeThreshold;
    final kinds = <(String, int)>[];
    final familyIds = CoinFamilies.all.take(spec.families).toList();
    // Tray heights: in fill mode each tray gets one of the listed heights,
    // spread evenly; otherwise every tray is [capacity] high.
    final caps = <int>[
      for (var i = 0; i < spec.stacks; i++)
        spec.fill
            ? spec.fillCapacities[i % spec.fillCapacities.length].clamp(
                2,
                spec.capacity,
              )
            : spec.capacity,
    ];
    if (spec.fill) rng.shuffle(caps);
    for (final (fi, f) in familyIds.indexed) {
      // A family's set size is one tray height it can be sealed in.
      final size = spec.fill
          ? spec.fillCapacities[rng.nextInt(spec.fillCapacities.length)].clamp(
              2,
              spec.capacity,
            )
          : k;
      final sets = spec.setsPerFamily + (fi < spec.extraSetFamilies ? 1 : 0);
      for (var set = 0; set < sets; set++) {
        if (spec.maxTier == 1) {
          for (var i = 0; i < size; i++) {
            kinds.add((f, 1));
          }
        } else {
          // One set at maxTier 2 is k tier-2 coins worth of value.
          final high = spec.higherTierCoins.clamp(0, k - 1);
          for (var i = 0; i < high; i++) {
            kinds.add((f, 2));
          }
          for (var i = 0; i < (k - high) * k; i++) {
            kinds.add((f, 1));
          }
        }
      }
    }
    final filled = spec.stacks - spec.emptyStacks;
    rng.shuffle(kinds);
    // At most half of the coins arrive by deal; the rest start on the board.
    final dealBatches = spec.dealSize == 0
        ? 0
        : spec.deals.clamp(0, (kinds.length ~/ 2) ~/ spec.dealSize);
    final dealCount = dealBatches * spec.dealSize;
    final dealt = kinds.sublist(kinds.length - dealCount);
    kinds.removeRange(kinds.length - dealCount, kinds.length);
    // Filled piles take the first trays in board order, empties the rest.
    final pileCap = [for (var i = 0; i < filled; i++) caps[i]];
    final room = pileCap.fold(0, (a, b) => a + b);
    // Leave slack: a board packed to the brim has no first move.
    if (kinds.length > room * (spec.fill ? 0.8 : 1.0)) return null;

    final piles = List.generate(filled, (_) => <(String, int)>[]);
    for (final kind in kinds) {
      // Deal into a random pile that still has room.
      final open = [
        for (var i = 0; i < filled; i++)
          if (piles[i].length < pileCap[i] - (spec.fill ? 1 : 0)) i,
      ];
      if (open.isEmpty) return null;
      piles[open[rng.nextInt(open.length)]].add(kind);
    }
    if (piles.where((p) => p.isEmpty).length > 1) return null;

    // Reject runs that would already fuse, and trivially sorted piles.
    for (var pi = 0; pi < piles.length; pi++) {
      final p = piles[pi];
      final limit = spec.fill ? pileCap[pi] : k;
      var run = 1;
      for (var i = 1; i < p.length; i++) {
        run = p[i] == p[i - 1] ? run + 1 : 1;
        if (run >= limit) return null;
      }
    }

    var coinSerial = 0;
    final stacks = <StackState>[];
    final coinSlots = <(int, int)>[];
    final built = <List<CoinState>>[];
    for (var i = 0; i < filled; i++) {
      final coins = <CoinState>[];
      for (var j = 0; j < piles[i].length; j++) {
        final (f, t) = piles[i][j];
        coins.add(CoinState(id: 'c${coinSerial++}', familyId: f, tier: t));
        if (j < piles[i].length - 1) coinSlots.add((i, j));
      }
      built.add(coins);
    }

    // Veil a share of non-top coins.
    if (spec.hiddenRatio > 0) {
      for (final (i, j) in coinSlots) {
        if (rng.nextDouble() < spec.hiddenRatio) {
          final c = built[i][j];
          built[i][j] = CoinState(
            id: c.id,
            familyId: c.familyId,
            tier: c.tier,
            specialType: SpecialCoinType.hidden,
            isRevealed: false,
          );
        }
      }
    }

    // Frost: picked among unveiled coins, top coins allowed.
    if (spec.frostCount > 0) {
      final candidates = <(int, int)>[
        for (var i = 0; i < filled; i++)
          for (var j = 0; j < built[i].length; j++)
            if (built[i][j].isRevealed) (i, j),
      ];
      rng.shuffle(candidates);
      for (final (i, j) in candidates.take(spec.frostCount)) {
        final c = built[i][j];
        built[i][j] = CoinState(
          id: c.id,
          familyId: c.familyId,
          tier: c.tier,
          specialType: SpecialCoinType.frosted,
          frost: spec.frostLevel,
        );
      }
    }

    // Interleave empty trays deterministically among filled ones.
    final order = [
      for (var i = 0; i < filled; i++) i,
      for (var i = 0; i < spec.emptyStacks; i++) -1,
    ];
    final emptyAtEnd = spec.frostCount == 0;
    if (!emptyAtEnd) rng.shuffle(order);
    var sid = 0;
    for (final o in order) {
      stacks.add(
        StackState(
          id: 's$sid',
          coins: o < 0 ? const [] : built[o],
          capacity: o < 0 ? caps[sid] : pileCap[o],
        ),
      );
      sid++;
    }
    // Deals: each batch scatters its coins over random trays, at most 3 per
    // tray, so presses feel like a spray rather than a single drop. The
    // first batch only targets trays with room at the start, so Deal is
    // never refused before the player has moved.
    final deals = <DealBatch>[];
    final free = [for (final s in stacks) s.freeSpace];
    for (var b = 0; b < dealBatches; b++) {
      final perStack = <int, List<CoinState>>{};
      for (var j = 0; j < spec.dealSize; j++) {
        final (f, t) = dealt[b * spec.dealSize + j];
        int target;
        var guard = 0;
        do {
          target = rng.nextInt(stacks.length);
        } while ((perStack[target]?.length ?? 0) >=
                (b == 0 ? math.min(3, free[target]) : 3) &&
            ++guard < 40);
        if (b == 0 && (perStack[target]?.length ?? 0) >= free[target]) {
          return null;
        }
        (perStack[target] ??= []).add(
          CoinState(id: 'c${coinSerial++}', familyId: f, tier: t),
        );
      }
      final order = perStack.keys.toList()..sort();
      deals.add(
        DealBatch([
          for (final i in order)
            DealDrop(stackId: stacks[i].id, coins: perStack[i]!),
        ]),
      );
    }
    return BoardState(
      stacks: stacks,
      rules: RuleSet(
        mergeThreshold: spec.fill ? caps.reduce((a, b) => a < b ? a : b) : k,
        maxTier: spec.maxTier,
        fillToSeal: spec.fill,
      ),
      deals: deals,
    );
  }
}
