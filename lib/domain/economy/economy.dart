import '../model/level.dart';
import '../progression/player_profile.dart';

/// Items purchasable with earned soft currency (Gilt). Prices are fixed in the
/// app; no premium currency exists.
enum ShopOffer {
  hintPack(cost: 60, item: InventoryItem.hint, quantity: 3),
  bonusTray(cost: 80, item: InventoryItem.bonusTray, quantity: 1);

  const ShopOffer({
    required this.cost,
    required this.item,
    required this.quantity,
  });

  final int cost;
  final InventoryItem item;
  final int quantity;
}

/// Cosmetic coin finishes. Visual only; never affect rules or odds.
enum CoinFinish {
  enamel(cost: 0),
  satin(cost: 150),
  gilded(cost: 300);

  const CoinFinish({required this.cost});

  final int cost;
}

/// Permanent top-row workshop slots, unlocked in order with earned gilt
/// after reaching a level. Prices stay modest: every level is solvable
/// without any of them.
final class WorkshopSlotSpec {
  const WorkshopSlotSpec({required this.afterLevel, required this.cost});

  /// Levels that must be completed first.
  final int afterLevel;
  final int cost;
}

abstract final class WorkshopCatalog {
  static const slots = [
    WorkshopSlotSpec(afterLevel: 3, cost: 40),
    WorkshopSlotSpec(afterLevel: 8, cost: 100),
    WorkshopSlotSpec(afterLevel: 15, cost: 200),
    WorkshopSlotSpec(afterLevel: 24, cost: 320),
    WorkshopSlotSpec(afterLevel: 32, cost: 480),
  ];
}

enum EconomyError {
  insufficientFunds,
  alreadyOwned,
  alreadyApplied,
  empty,
  unknown,
  notYet,
}

final class EconomyResult {
  const EconomyResult.ok(this.profile, {this.granted = 0}) : error = null;
  const EconomyResult.failed(this.profile, this.error) : granted = 0;

  final PlayerProfile profile;
  final EconomyError? error;

  /// Gilt granted by this operation (0 if none or already applied).
  final int granted;

  bool get isOk => error == null;
}

/// Pure economy rules. Every grant is keyed by an idempotency id, so replays
/// (duplicate callbacks, relaunch after a crash mid-save) never double-pay.
abstract final class Economy {
  static const int tutorialHintBonus = 2;
  static const int stipendAmount = 15;

  static EconomyResult completeLevel(
    PlayerProfile p,
    LevelDefinition level, {
    required int moves,
    required DateTime now,
  }) {
    final prior = p.completions[level.id];
    final record = CompletionRecord(
      levelVersion: level.version,
      bestMoves: prior == null || moves < prior.bestMoves
          ? moves
          : prior.bestMoves,
      firstCompletedAt: prior?.firstCompletedAt ?? now,
    );
    var next = p.copyWith(
      completions: {...p.completions, level.id: record},
      tutorialDone: p.tutorialDone || level.isTutorial,
      levelsCompletedSinceInterstitial: p.levelsCompletedSinceInterstitial + 1,
    );
    final key = 'level:${level.id}';
    if (next.appliedTransactions.contains(key)) {
      return EconomyResult.ok(next);
    }
    next = _credit(next, key, level.reward, 'level ${level.id}', now);
    if (level.isTutorial) {
      next = next.copyWith(
        inventory: _add(next.inventory, InventoryItem.hint, tutorialHintBonus),
      );
    }
    return EconomyResult.ok(next, granted: level.reward);
  }

  static EconomyResult buy(
    PlayerProfile p,
    ShopOffer offer, {
    required String txId,
    required DateTime now,
  }) {
    if (p.appliedTransactions.contains(txId)) {
      return EconomyResult.failed(p, EconomyError.alreadyApplied);
    }
    if (p.gilt < offer.cost) {
      return EconomyResult.failed(p, EconomyError.insufficientFunds);
    }
    final next = _credit(p, txId, -offer.cost, 'shop ${offer.name}', now);
    return EconomyResult.ok(
      next.copyWith(
        inventory: _add(next.inventory, offer.item, offer.quantity),
      ),
    );
  }

  static EconomyResult buyFinish(
    PlayerProfile p,
    CoinFinish finish, {
    required DateTime now,
  }) {
    if (p.ownedFinishes.contains(finish.name)) {
      return EconomyResult.failed(p, EconomyError.alreadyOwned);
    }
    if (p.gilt < finish.cost) {
      return EconomyResult.failed(p, EconomyError.insufficientFunds);
    }
    final next = _credit(
      p,
      'finish:${finish.name}',
      -finish.cost,
      'finish ${finish.name}',
      now,
    );
    return EconomyResult.ok(
      next.copyWith(
        ownedFinishes: {...next.ownedFinishes, finish.name},
        activeFinish: finish.name,
      ),
    );
  }

  /// Consumes one item. Callers spend only after the effect is confirmed
  /// (e.g. a hint was actually found).
  static EconomyResult consume(PlayerProfile p, InventoryItem item) {
    if (p.count(item) <= 0) return EconomyResult.failed(p, EconomyError.empty);
    return EconomyResult.ok(p.copyWith(inventory: _add(p.inventory, item, -1)));
  }

  /// Grants an item from a verified external event (rewarded ad completion).
  static EconomyResult grantItem(
    PlayerProfile p,
    InventoryItem item,
    int qty, {
    required String txId,
  }) {
    if (p.appliedTransactions.contains(txId)) {
      return EconomyResult.failed(p, EconomyError.alreadyApplied);
    }
    return EconomyResult.ok(
      p.copyWith(
        inventory: _add(p.inventory, item, qty),
        appliedTransactions: {...p.appliedTransactions, txId},
      ),
    );
  }

  /// Optional, forgiving daily gift: no streaks, nothing lost by skipping.
  static EconomyResult claimStipend(PlayerProfile p, {required DateTime now}) {
    final day = dayKey(now);
    if (p.lastStipendDay == day) {
      return EconomyResult.failed(p, EconomyError.alreadyApplied);
    }
    final next = _credit(
      p,
      'stipend:$day',
      stipendAmount,
      'daily stipend',
      now,
    ).copyWith(lastStipendDay: day);
    return EconomyResult.ok(next, granted: stipendAmount);
  }

  static bool stipendAvailable(PlayerProfile p, DateTime now) =>
      p.lastStipendDay != dayKey(now);

  /// Unlocks the next workshop slot. Slots unlock strictly in order.
  static EconomyError? workshopBlocker(PlayerProfile p, int index) {
    if (index < p.workshopSlots) return EconomyError.alreadyOwned;
    if (index != p.workshopSlots || index >= WorkshopCatalog.slots.length) {
      return EconomyError.notYet;
    }
    final spec = WorkshopCatalog.slots[index];
    if (p.completions.length < spec.afterLevel) return EconomyError.notYet;
    if (p.gilt < spec.cost) return EconomyError.insufficientFunds;
    return null;
  }

  static EconomyResult unlockWorkshopSlot(
    PlayerProfile p,
    int index, {
    required DateTime now,
  }) {
    final blocker = workshopBlocker(p, index);
    if (blocker != null) return EconomyResult.failed(p, blocker);
    final spec = WorkshopCatalog.slots[index];
    final next = _credit(
      p,
      'workshop:$index',
      -spec.cost,
      'workshop slot ${index + 1}',
      now,
    ).copyWith(workshopSlots: index + 1);
    return EconomyResult.ok(next);
  }

  /// Applies a store entitlement exactly once per transaction id.
  static EconomyResult applyEntitlement(
    PlayerProfile p,
    String productId, {
    required String txId,
  }) {
    final key = 'iap:$txId';
    if (p.appliedTransactions.contains(key)) {
      return EconomyResult.failed(p, EconomyError.alreadyApplied);
    }
    final applied = {...p.appliedTransactions, key};
    return switch (productId) {
      'remove_ads' => EconomyResult.ok(
        p.copyWith(removeAds: true, appliedTransactions: applied),
      ),
      _ => EconomyResult.failed(p, EconomyError.unknown),
    };
  }

  static String dayKey(DateTime t) {
    final l = t.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)}';
  }

  static PlayerProfile _credit(
    PlayerProfile p,
    String id,
    int amount,
    String reason,
    DateTime now,
  ) {
    final ledger = [
      ...p.ledger,
      LedgerEntry(id: id, amount: amount, reason: reason, at: now),
    ];
    return p.copyWith(
      gilt: p.gilt + amount,
      appliedTransactions: {...p.appliedTransactions, id},
      ledger: ledger.length > PlayerProfile.ledgerLimit
          ? ledger.sublist(ledger.length - PlayerProfile.ledgerLimit)
          : ledger,
    );
  }

  static Map<InventoryItem, int> _add(
    Map<InventoryItem, int> inv,
    InventoryItem item,
    int delta,
  ) => {...inv, item: (inv[item] ?? 0) + delta};
}
