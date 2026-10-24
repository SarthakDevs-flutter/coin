import 'coin.dart';

/// Ordered log of what a committed transition did. The presentation layer
/// animates these; it never derives game state from them.
sealed class DomainEvent {
  const DomainEvent();
}

/// [coinIds] (bottom→top order) left [fromStack] and landed in [toStack]
/// starting at slot [toIndex].
final class CoinsMoved extends DomainEvent {
  const CoinsMoved({
    required this.coinIds,
    required this.fromStack,
    required this.toStack,
    required this.toIndex,
  });

  final List<String> coinIds;
  final String fromStack;
  final String toStack;
  final int toIndex;
}

/// A deal dropped coins: per tray, [coinIds] landed from slot [toIndex].
final class CoinsDealt extends DomainEvent {
  const CoinsDealt(this.drops);

  final List<({String stackId, List<String> coinIds, int toIndex})> drops;
}

/// [consumedIds] fused at slot [atIndex] of [stackId]. When [produced] is
/// null the set was sealed (removed from the board).
final class CoinsFused extends DomainEvent {
  const CoinsFused({
    required this.stackId,
    required this.consumedIds,
    required this.atIndex,
    required this.produced,
  });

  final String stackId;
  final List<String> consumedIds;
  final int atIndex;
  final CoinState? produced;

  bool get isSeal => produced == null;
}

final class CoinThawed extends DomainEvent {
  const CoinThawed({required this.coinId, required this.remaining});

  final String coinId;
  final int remaining;
}

final class CoinRevealed extends DomainEvent {
  const CoinRevealed(this.coin);

  final CoinState coin;
}

final class ObjectiveCompleted extends DomainEvent {
  const ObjectiveCompleted();
}
