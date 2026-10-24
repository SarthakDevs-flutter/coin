/// Special behaviours a coin can carry. Every type listed here has a written
/// rule in docs/rules.md, solver support, and tests. New types must meet the
/// same bar before they are added (features-and-flows.md §5.4).
enum SpecialCoinType {
  /// Ordinary enamel coin.
  none,

  /// Frost seal: cannot be lifted, matched or covered while [CoinState.frost]
  /// is above zero. Each merge or seal in its own stack or a neighbouring stack
  /// thaws it by one.
  frosted,

  /// Veiled coin: identity is hidden until it becomes the top coin of its
  /// stack. Once revealed it stays revealed. The level data always knows the
  /// true identity, so solvability never depends on luck.
  hidden,
}

/// Immutable coin value. Identity for matching is (familyId, tier).
final class CoinState {
  const CoinState({
    required this.id,
    required this.familyId,
    this.tier = 1,
    this.specialType = SpecialCoinType.none,
    this.frost = 0,
    this.isRevealed = true,
  }) : assert(tier >= 1),
       assert(frost >= 0);

  final String id;
  final String familyId;
  final int tier;
  final SpecialCoinType specialType;

  /// Remaining thaw count for frosted coins. Zero means free.
  final int frost;

  /// False only for veiled coins that have never been the top coin.
  final bool isRevealed;

  bool get isFrozen => frost > 0;

  /// A coin can take part in a lift/match run only when the player can see it
  /// and it is not sealed by frost.
  bool get isActive => isRevealed && !isFrozen;

  bool sameKindAs(CoinState other) =>
      familyId == other.familyId && tier == other.tier;

  CoinState copyWith({int? frost, bool? isRevealed}) => CoinState(
    id: id,
    familyId: familyId,
    tier: tier,
    specialType: specialType,
    frost: frost ?? this.frost,
    isRevealed: isRevealed ?? this.isRevealed,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'family': familyId,
    if (tier != 1) 'tier': tier,
    if (specialType != SpecialCoinType.none) 'special': specialType.name,
    if (frost != 0) 'frost': frost,
    if (!isRevealed) 'revealed': false,
  };

  factory CoinState.fromJson(Map<String, Object?> json) {
    final special = json['special'] as String?;
    return CoinState(
      id: json['id']! as String,
      familyId: json['family']! as String,
      tier: (json['tier'] as int?) ?? 1,
      specialType: special == null
          ? SpecialCoinType.none
          : SpecialCoinType.values.byName(special),
      frost: (json['frost'] as int?) ?? 0,
      isRevealed: (json['revealed'] as bool?) ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CoinState &&
      other.id == id &&
      other.familyId == familyId &&
      other.tier == tier &&
      other.specialType == specialType &&
      other.frost == frost &&
      other.isRevealed == isRevealed;

  @override
  int get hashCode =>
      Object.hash(id, familyId, tier, specialType, frost, isRevealed);

  @override
  String toString() =>
      'Coin($id $familyId/t$tier${isFrozen ? ' frost$frost' : ''}'
      '${isRevealed ? '' : ' hidden'})';
}
