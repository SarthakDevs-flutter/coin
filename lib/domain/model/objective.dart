import 'board.dart';

/// What a level asks the player to achieve. Always explicit per level.
sealed class ObjectiveDefinition {
  const ObjectiveDefinition();

  bool isMet(BoardState state);

  Map<String, Object?> toJson();

  static ObjectiveDefinition fromJson(Map<String, Object?> json) =>
      switch (json['type']) {
        'clearBoard' => const ClearBoardObjective(),
        'forge' => ForgeObjective(
          tier: json['tier']! as int,
          count: json['count']! as int,
        ),
        final t => throw FormatException('Unknown objective type $t'),
      };
}

/// Seal every coin: the board must end empty with no deals left.
final class ClearBoardObjective extends ObjectiveDefinition {
  const ClearBoardObjective();

  @override
  bool isMet(BoardState state) =>
      state.coinCount == 0 && !state.hasPendingDeals;

  @override
  Map<String, Object?> toJson() => {'type': 'clearBoard'};

  @override
  bool operator ==(Object other) => other is ClearBoardObjective;

  @override
  int get hashCode => 1;
}

/// Forge [count] coins of [tier] (created by fusing; starting coins of that
/// tier do not count).
final class ForgeObjective extends ObjectiveDefinition {
  const ForgeObjective({required this.tier, required this.count})
    : assert(tier >= 2),
      assert(count >= 1);

  final int tier;
  final int count;

  @override
  bool isMet(BoardState state) => state.progress.forgedOfTier(tier) >= count;

  @override
  Map<String, Object?> toJson() => {
    'type': 'forge',
    'tier': tier,
    'count': count,
  };

  @override
  bool operator ==(Object other) =>
      other is ForgeObjective && other.tier == tier && other.count == count;

  @override
  int get hashCode => Object.hash(tier, count);
}

/// Monotonic counters derived from resolved merges. Stored in the board so
/// undo restores them exactly.
final class ObjectiveProgress {
  const ObjectiveProgress._(this.forged, this.sealed, this.sealedCoins);

  factory ObjectiveProgress({
    required Map<int, int> forged,
    required int sealed,
    int sealedCoins = 0,
  }) => ObjectiveProgress._(Map.unmodifiable(forged), sealed, sealedCoins);

  static const empty = ObjectiveProgress._({}, 0, 0);

  /// Number of coins created per tier.
  final Map<int, int> forged;

  /// Number of sets sealed (removed from the board).
  final int sealed;

  /// Coins those sets contained (set sizes vary in fill mode).
  final int sealedCoins;

  int forgedOfTier(int tier) => forged[tier] ?? 0;

  ObjectiveProgress withForged(int tier) => ObjectiveProgress(
    forged: {...forged, tier: forgedOfTier(tier) + 1},
    sealed: sealed,
    sealedCoins: sealedCoins,
  );

  ObjectiveProgress withSealed(int coins) => ObjectiveProgress(
    forged: forged,
    sealed: sealed + 1,
    sealedCoins: sealedCoins + coins,
  );

  Map<String, Object?> toJson() => {
    'forged': {for (final e in forged.entries) '${e.key}': e.value},
    'sealed': sealed,
    if (sealedCoins > 0) 'sealedCoins': sealedCoins,
  };

  factory ObjectiveProgress.fromJson(Map<String, Object?> json) =>
      ObjectiveProgress(
        forged: {
          for (final e in ((json['forged'] as Map?) ?? const {}).entries)
            int.parse(e.key as String): e.value as int,
        },
        sealed: (json['sealed'] as int?) ?? 0,
        sealedCoins: (json['sealedCoins'] as int?) ?? 0,
      );

  @override
  bool operator ==(Object other) {
    if (other is! ObjectiveProgress ||
        other.sealed != sealed ||
        other.sealedCoins != sealedCoins) {
      return false;
    }
    if (other.forged.length != forged.length) return false;
    for (final e in forged.entries) {
      if (other.forged[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    sealed,
    sealedCoins,
    Object.hashAllUnordered(
      forged.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}
