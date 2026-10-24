import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'coin.dart';
import 'objective.dart';

/// Ordered pile of coins. Convention (used everywhere): index 0 is the bottom
/// coin, `coins.last` is the top coin.
final class StackState {
  StackState({
    required this.id,
    required List<CoinState> coins,
    required this.capacity,
    this.isBonus = false,
    this.isWorkshop = false,
  }) : coins = List.unmodifiable(coins),
       assert(capacity > 0);

  final String id;
  final List<CoinState> coins;
  final int capacity;

  /// True for the extra tray added by the booster.
  final bool isBonus;

  /// A permanent workshop slot the player unlocked (top row).
  final bool isWorkshop;

  /// Bonus and workshop trays are extras: never part of a level's design,
  /// never frost neighbours. They only add options, so solvability holds.
  bool get isAuxiliary => isBonus || isWorkshop;

  bool get isEmpty => coins.isEmpty;
  bool get isFull => coins.length >= capacity;
  int get freeSpace => capacity - coins.length;
  CoinState? get top => coins.isEmpty ? null : coins.last;

  /// Length of the contiguous run of identical, active coins at the top.
  int get topRunLength {
    final t = top;
    if (t == null || !t.isActive) return 0;
    var n = 0;
    for (var i = coins.length - 1; i >= 0; i--) {
      final c = coins[i];
      if (!c.isActive || !c.sameKindAs(t)) break;
      n++;
    }
    return n;
  }

  StackState withCoins(List<CoinState> next) => StackState(
    id: id,
    coins: next,
    capacity: capacity,
    isBonus: isBonus,
    isWorkshop: isWorkshop,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'capacity': capacity,
    if (isBonus) 'bonus': true,
    if (isWorkshop) 'workshop': true,
    'coins': [for (final c in coins) c.toJson()],
  };

  factory StackState.fromJson(Map<String, Object?> json) => StackState(
    id: json['id']! as String,
    capacity: json['capacity']! as int,
    isBonus: (json['bonus'] as bool?) ?? false,
    isWorkshop: (json['workshop'] as bool?) ?? false,
    coins: [
      for (final c in json['coins']! as List)
        CoinState.fromJson((c as Map).cast<String, Object?>()),
    ],
  );

  @override
  bool operator ==(Object other) =>
      other is StackState &&
      other.id == id &&
      other.capacity == capacity &&
      other.isBonus == isBonus &&
      other.isWorkshop == isWorkshop &&
      _listEq(other.coins, coins);

  @override
  int get hashCode =>
      Object.hash(id, capacity, isBonus, isWorkshop, Object.hashAll(coins));
}

/// Rule parameters for a level. Part of the board so the rules engine and the
/// solver never depend on anything outside the state they are given.
final class RuleSet {
  const RuleSet({
    required this.mergeThreshold,
    required this.maxTier,
    this.fillToSeal = false,
  });

  /// Number of identical coins that fuse when they meet at the top of a stack
  /// (classic rule). In fill mode it is the smallest tray height, kept for
  /// sizing extra trays.
  final int mergeThreshold;

  /// Fusing coins of this tier seals them into the cabinet (they leave the
  /// board). Below it, they fuse into one coin of the next tier.
  final int maxTier;

  /// Fill mode (rules v3): a tray seals when it is full of one kind, so each
  /// tray's height is its own set size. Single tier only.
  final bool fillToSeal;

  /// Coins of one kind that seal (or fuse) in [stack].
  int thresholdFor(StackState stack) =>
      fillToSeal ? stack.capacity : mergeThreshold;

  Map<String, Object?> toJson() => {
    'mergeThreshold': mergeThreshold,
    'maxTier': maxTier,
    if (fillToSeal) 'fill': true,
  };

  factory RuleSet.fromJson(Map<String, Object?> json) => RuleSet(
    mergeThreshold: json['mergeThreshold']! as int,
    maxTier: json['maxTier']! as int,
    fillToSeal: (json['fill'] as bool?) ?? false,
  );

  @override
  bool operator ==(Object other) =>
      other is RuleSet &&
      other.mergeThreshold == mergeThreshold &&
      other.maxTier == maxTier &&
      other.fillToSeal == fillToSeal;

  @override
  int get hashCode => Object.hash(mergeThreshold, maxTier, fillToSeal);
}

/// Coins a deal drops onto one tray, bottom→top.
final class DealDrop {
  DealDrop({required this.stackId, required List<CoinState> coins})
    : coins = List.unmodifiable(coins);

  final String stackId;
  final List<CoinState> coins;

  Map<String, Object?> toJson() => {
    'stack': stackId,
    'coins': [for (final c in coins) c.toJson()],
  };

  factory DealDrop.fromJson(Map<String, Object?> json) => DealDrop(
    stackId: json['stack']! as String,
    coins: [
      for (final c in json['coins']! as List)
        CoinState.fromJson((c as Map).cast()),
    ],
  );
}

/// One press of the Deal button. Fixed in level data, so deals are fully
/// deterministic and visible in advance (design spec v2 §2.1).
final class DealBatch {
  DealBatch(List<DealDrop> drops) : drops = List.unmodifiable(drops);

  final List<DealDrop> drops;

  int get coinCount => drops.fold(0, (n, d) => n + d.coins.length);

  Iterable<CoinState> get coins => drops.expand((d) => d.coins);

  Map<String, Object?> toJson() => {
    'drops': [for (final d in drops) d.toJson()],
  };

  factory DealBatch.fromJson(Map<String, Object?> json) => DealBatch([
    for (final d in json['drops']! as List)
      DealDrop.fromJson((d as Map).cast()),
  ]);
}

/// Complete, authoritative puzzle state. Immutable; every change goes through
/// the rules engine and produces a new instance.
final class BoardState {
  BoardState({
    required List<StackState> stacks,
    required this.rules,
    this.moveCount = 0,
    this.nextCoinSerial = 0,
    this.progress = ObjectiveProgress.empty,
    List<DealBatch> deals = const [],
    this.dealIndex = 0,
  }) : stacks = List.unmodifiable(stacks),
       deals = List.unmodifiable(deals);

  /// v2 added deals. v1 boards load unchanged (no deals).
  static const int rulesVersion = 3;

  final List<StackState> stacks;
  final RuleSet rules;
  final int moveCount;

  /// Deterministic counter for IDs of coins created by fusing.
  final int nextCoinSerial;
  final ObjectiveProgress progress;

  /// The level's full deal queue (static) and how many batches were dealt.
  final List<DealBatch> deals;
  final int dealIndex;

  bool get hasPendingDeals => dealIndex < deals.length;
  DealBatch? get nextDeal => hasPendingDeals ? deals[dealIndex] : null;
  int get dealsLeft => deals.length - dealIndex;

  int indexOfStack(String id) => stacks.indexWhere((s) => s.id == id);

  StackState? stackById(String id) {
    final i = indexOfStack(id);
    return i < 0 ? null : stacks[i];
  }

  int get coinCount => stacks.fold(0, (n, s) => n + s.coins.length);

  BoardState copyWith({
    List<StackState>? stacks,
    int? moveCount,
    int? nextCoinSerial,
    ObjectiveProgress? progress,
    int? dealIndex,
  }) => BoardState(
    stacks: stacks ?? this.stacks,
    rules: rules,
    moveCount: moveCount ?? this.moveCount,
    nextCoinSerial: nextCoinSerial ?? this.nextCoinSerial,
    progress: progress ?? this.progress,
    deals: deals,
    dealIndex: dealIndex ?? this.dealIndex,
  );

  Map<String, Object?> toJson() => {
    'rulesVersion': rulesVersion,
    'rules': rules.toJson(),
    'moveCount': moveCount,
    'nextCoinSerial': nextCoinSerial,
    'progress': progress.toJson(),
    'stacks': [for (final s in stacks) s.toJson()],
    if (deals.isNotEmpty) 'deals': [for (final d in deals) d.toJson()],
    if (dealIndex != 0) 'dealIndex': dealIndex,
  };

  factory BoardState.fromJson(Map<String, Object?> json) {
    final version = (json['rulesVersion'] as int?) ?? rulesVersion;
    if (version < 1 || version > rulesVersion) {
      throw FormatException('Unsupported rules version $version');
    }
    return BoardState(
      rules: RuleSet.fromJson((json['rules']! as Map).cast()),
      moveCount: (json['moveCount'] as int?) ?? 0,
      nextCoinSerial: (json['nextCoinSerial'] as int?) ?? 0,
      progress: json['progress'] == null
          ? ObjectiveProgress.empty
          : ObjectiveProgress.fromJson((json['progress']! as Map).cast()),
      stacks: [
        for (final s in json['stacks']! as List)
          StackState.fromJson((s as Map).cast()),
      ],
      deals: [
        for (final d in (json['deals'] as List?) ?? const [])
          DealBatch.fromJson((d as Map).cast()),
      ],
      dealIndex: (json['dealIndex'] as int?) ?? 0,
    );
  }

  /// Stable fingerprint of every rule-relevant field; used for diagnostics,
  /// the debug overlay and crash reports (never contains personal data).
  String get stateHash => sha256
      .convert(utf8.encode(jsonEncode(toJson())))
      .toString()
      .substring(0, 12);

  @override
  bool operator ==(Object other) =>
      other is BoardState &&
      other.rules == rules &&
      other.moveCount == moveCount &&
      other.nextCoinSerial == nextCoinSerial &&
      other.progress == progress &&
      other.dealIndex == dealIndex &&
      other.deals.length == deals.length &&
      _listEq(other.stacks, stacks);

  @override
  int get hashCode => Object.hash(
    rules,
    moveCount,
    nextCoinSerial,
    progress,
    dealIndex,
    Object.hashAll(stacks),
  );
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
