import '../model/board.dart';
import '../model/coin.dart';
import '../model/events.dart';
import '../model/move.dart';
import '../model/objective.dart';

/// Why a move was rejected. Shown to the player as a short, blame-free message.
enum MoveRejection {
  unknownStack,
  sameStack,
  sourceEmpty,
  sourceFrozen,
  destinationFull,
  destinationFrozen,
  mismatch,
  noDealsLeft,
  dealNoRoom,
}

final class MoveValidation {
  const MoveValidation.ok(this.count) : rejection = null;
  const MoveValidation.rejected(MoveRejection this.rejection) : count = 0;

  final MoveRejection? rejection;

  /// Number of coins that would move.
  final int count;

  bool get isLegal => rejection == null;
}

final class MoveResolution {
  const MoveResolution({
    required this.previous,
    required this.next,
    required this.events,
  });

  final BoardState previous;
  final BoardState next;
  final List<DomainEvent> events;
}

/// Raised when a resolution would break a board invariant or fail to settle.
/// Indicates a defect, never a player error.
final class RulesInvariantError extends Error {
  RulesInvariantError(this.message);
  final String message;

  @override
  String toString() => 'RulesInvariantError: $message';
}

/// The single canonical implementation of the puzzle rules. Gameplay, hints,
/// blocked-board detection, the solver and the level tools all call this.
///
/// Rules (v1):
/// 1. A move lifts the top run (contiguous identical, visible, unfrozen coins)
///    of the source stack.
/// 2. It may land on an empty stack, or on a stack whose top coin is the same
///    kind and not frozen.
/// 3. Coins move one at a time until the source run is exhausted, the
///    destination is full, or the destination run reaches the merge threshold.
/// 4. When a stack's top run reaches its threshold, those coins fuse: below
///    `maxTier` into one coin of the next tier, at `maxTier` they are sealed.
///    The threshold is the rule set's merge count, or in fill mode (v3) the
///    tray's own height: a tray full of one kind seals.
/// 5. Every fuse thaws frosted coins in that stack and both neighbours by 1.
/// 6. Top coins are always revealed. Resolution repeats (destination stack
///    first, then board order) until no stack can fuse.
final class RulesEngine {
  const RulesEngine();

  static const int maxResolutionSteps = 256;

  MoveValidation validate(BoardState state, MoveCommand move) {
    if (move.isDeal) return validateDeal(state);
    final si = state.indexOfStack(move.from);
    final di = state.indexOfStack(move.to);
    if (si < 0 || di < 0) {
      return const MoveValidation.rejected(MoveRejection.unknownStack);
    }
    if (si == di) return const MoveValidation.rejected(MoveRejection.sameStack);
    final src = state.stacks[si];
    final dst = state.stacks[di];
    final top = src.top;
    if (top == null) {
      return const MoveValidation.rejected(MoveRejection.sourceEmpty);
    }
    if (!top.isActive) {
      return const MoveValidation.rejected(MoveRejection.sourceFrozen);
    }
    if (dst.isFull) {
      return const MoveValidation.rejected(MoveRejection.destinationFull);
    }
    final threshold = state.rules.thresholdFor(dst);
    final run = src.topRunLength;
    final dTop = dst.top;
    int room;
    if (dTop == null) {
      room = threshold;
    } else {
      if (dTop.isFrozen) {
        return const MoveValidation.rejected(MoveRejection.destinationFrozen);
      }
      if (!dTop.isActive || !dTop.sameKindAs(top)) {
        return const MoveValidation.rejected(MoveRejection.mismatch);
      }
      room = threshold - dst.topRunLength;
    }
    final count = _min3(run, dst.freeSpace, room);
    if (count <= 0) {
      // Cannot happen on a settled board; treat as mismatch defensively.
      return const MoveValidation.rejected(MoveRejection.mismatch);
    }
    return MoveValidation.ok(count);
  }

  /// A deal is legal when a batch remains and every tray it targets has room
  /// for all of its coins. [MoveValidation.count] is the batch size.
  MoveValidation validateDeal(BoardState state) {
    final batch = state.nextDeal;
    if (batch == null) {
      return const MoveValidation.rejected(MoveRejection.noDealsLeft);
    }
    if (dealBlockedStacks(state).isNotEmpty) {
      return const MoveValidation.rejected(MoveRejection.dealNoRoom);
    }
    return MoveValidation.ok(batch.coinCount);
  }

  /// Trays that lack room for the next deal (shown to the player).
  List<String> dealBlockedStacks(BoardState state) {
    final batch = state.nextDeal;
    if (batch == null) return const [];
    return [
      for (final d in batch.drops)
        if ((state.stackById(d.stackId)?.freeSpace ?? 0) < d.coins.length)
          d.stackId,
    ];
  }

  bool isLegal(BoardState state, MoveCommand move) =>
      validate(state, move).isLegal;

  /// Every legal move, in board order. Used by UI highlights, hints and
  /// blocked-board detection so they never disagree with gameplay.
  List<MoveCommand> legalMoves(BoardState state) {
    final out = <MoveCommand>[];
    for (final a in state.stacks) {
      final top = a.top;
      if (top == null || !top.isActive) continue;
      for (final b in state.stacks) {
        if (identical(a, b)) continue;
        final m = MoveCommand(a.id, b.id);
        if (validate(state, m).isLegal) out.add(m);
      }
    }
    if (validateDeal(state).isLegal) out.add(MoveCommand.deal);
    return out;
  }

  List<String> legalDestinations(BoardState state, String from) => [
    for (final m in legalMoves(state))
      if (m.from == from) m.to,
  ];

  bool canLift(BoardState state, String stackId) {
    final s = state.stackById(stackId);
    return s != null && s.top != null && s.top!.isActive;
  }

  /// Applies a move. Throws [ArgumentError] if the move is illegal: callers
  /// must validate first (the session always does).
  MoveResolution apply(
    BoardState state,
    MoveCommand move, {
    ObjectiveDefinition? objective,
    bool recordEvents = true,
  }) {
    final v = validate(state, move);
    if (!v.isLegal) {
      throw ArgumentError('Illegal move $move: ${v.rejection}');
    }
    final events = <DomainEvent>[];
    final stacks = [for (final s in state.stacks) List<CoinState>.of(s.coins)];
    int preferred;
    var dealIndex = state.dealIndex;
    if (move.isDeal) {
      final batch = state.nextDeal!;
      final drops = <({String stackId, List<String> coinIds, int toIndex})>[];
      for (final d in batch.drops) {
        final pile = stacks[state.indexOfStack(d.stackId)];
        drops.add((
          stackId: d.stackId,
          coinIds: [for (final c in d.coins) c.id],
          toIndex: pile.length,
        ));
        pile.addAll(d.coins);
      }
      dealIndex++;
      preferred = state.indexOfStack(batch.drops.first.stackId);
      if (recordEvents) events.add(CoinsDealt(drops));
    } else {
      final si = state.indexOfStack(move.from);
      final di = state.indexOfStack(move.to);
      final src = stacks[si];
      final dst = stacks[di];
      final moving = src.sublist(src.length - v.count);
      src.removeRange(src.length - v.count, src.length);
      final toIndex = dst.length;
      dst.addAll(moving);
      preferred = di;
      if (recordEvents) {
        events.add(
          CoinsMoved(
            coinIds: [for (final c in moving) c.id],
            fromStack: move.from,
            toStack: move.to,
            toIndex: toIndex,
          ),
        );
      }
    }

    var serial = state.nextCoinSerial;
    var progress = state.progress;
    final thresholds = [
      for (final s in state.stacks) state.rules.thresholdFor(s),
    ];
    final maxTier = state.rules.maxTier;

    var steps = 0;
    while (true) {
      if (++steps > maxResolutionSteps) {
        throw RulesInvariantError('resolution did not settle for $move');
      }
      _revealTops(stacks, events, recordEvents);
      final fuseAt = _firstFusable(stacks, thresholds, preferred: preferred);
      if (fuseAt < 0) break;
      final pile = stacks[fuseAt];
      final start = pile.length - thresholds[fuseAt];
      final consumed = pile.sublist(start);
      pile.removeRange(start, pile.length);
      final kind = consumed.first;
      CoinState? produced;
      if (kind.tier < maxTier) {
        produced = CoinState(
          id: 'f$serial',
          familyId: kind.familyId,
          tier: kind.tier + 1,
        );
        serial++;
        pile.add(produced);
        progress = progress.withForged(produced.tier);
      } else {
        progress = progress.withSealed(consumed.length);
      }
      if (recordEvents) {
        events.add(
          CoinsFused(
            stackId: state.stacks[fuseAt].id,
            consumedIds: [for (final c in consumed) c.id],
            atIndex: start,
            produced: produced,
          ),
        );
      }
      _thawAround(state.stacks, stacks, fuseAt, events, recordEvents);
    }

    final next = BoardState(
      stacks: [
        for (var i = 0; i < stacks.length; i++)
          state.stacks[i].withCoins(stacks[i]),
      ],
      rules: state.rules,
      moveCount: state.moveCount + 1,
      nextCoinSerial: serial,
      progress: progress,
      deals: state.deals,
      dealIndex: dealIndex,
    );
    assert(_coinsConserved(state, next));
    if (recordEvents &&
        objective != null &&
        !objective.isMet(state) &&
        objective.isMet(next)) {
      events.add(const ObjectiveCompleted());
    }
    return MoveResolution(previous: state, next: next, events: events);
  }

  /// Brings a freshly loaded board into its settled form (tops revealed).
  /// Level validation rejects boards that would fuse here.
  BoardState settle(BoardState state) {
    final stacks = [for (final s in state.stacks) List<CoinState>.of(s.coins)];
    _revealTops(stacks, null, false);
    return state.copyWith(
      stacks: [
        for (var i = 0; i < stacks.length; i++)
          state.stacks[i].withCoins(stacks[i]),
      ],
    );
  }

  /// Adds an empty bonus tray (booster). Not a move: does not change
  /// moveCount.
  BoardState addBonusStack(BoardState state, {required String id}) {
    final capacity = state.stacks
        .map((s) => s.capacity)
        .fold(state.rules.mergeThreshold, (a, b) => a > b ? a : b);
    return state.copyWith(
      stacks: [
        ...state.stacks,
        StackState(id: id, coins: const [], capacity: capacity, isBonus: true),
      ],
    );
  }

  static const int workshopMaxCapacity = 6;

  /// Appends workshop slot [index] as an empty tray: as deep as the level's
  /// trays up to [workshopMaxCapacity], never below the fuse count.
  BoardState addWorkshopStack(BoardState state, int index) {
    final largest = state.stacks
        .where((s) => !s.isAuxiliary)
        .map((s) => s.capacity)
        .fold(state.rules.mergeThreshold, (a, b) => a > b ? a : b);
    final k = state.rules.mergeThreshold;
    // Fill mode: a set is a full tray, so extra trays match the level's.
    final capacity = state.rules.fillToSeal || largest < workshopMaxCapacity
        ? largest
        : (k > workshopMaxCapacity ? k : workshopMaxCapacity);
    return state.copyWith(
      stacks: [
        ...state.stacks,
        StackState(
          id: 'w$index',
          coins: const [],
          capacity: capacity,
          isWorkshop: true,
        ),
      ],
    );
  }

  /// Structural invariants that must hold for every committed board.
  List<String> invariantViolations(BoardState state) {
    final problems = <String>[];
    final ids = <String>{};
    final stackIds = <String>{};
    if (state.rules.fillToSeal && state.rules.maxTier != 1) {
      problems.add('fill mode needs a single tier');
    }
    for (final s in state.stacks) {
      if (!stackIds.add(s.id)) problems.add('duplicate stack ${s.id}');
      if (s.coins.length > s.capacity) problems.add('overfull ${s.id}');
      if (s.top != null && !s.top!.isRevealed) {
        problems.add('hidden top in ${s.id}');
      }
      if (s.topRunLength >= state.rules.thresholdFor(s)) {
        problems.add('unsettled run in ${s.id}');
      }
      for (final c in s.coins) {
        if (!ids.add(c.id)) problems.add('duplicate coin ${c.id}');
        if (c.tier > state.rules.maxTier) problems.add('tier overflow ${c.id}');
      }
    }
    for (var i = state.dealIndex; i < state.deals.length; i++) {
      for (final d in state.deals[i].drops) {
        if (!stackIds.contains(d.stackId)) {
          problems.add('deal targets unknown ${d.stackId}');
        }
        for (final c in d.coins) {
          if (!ids.add(c.id)) problems.add('duplicate coin ${c.id}');
        }
      }
    }
    return problems;
  }

  void _revealTops(
    List<List<CoinState>> stacks,
    List<DomainEvent>? events,
    bool record,
  ) {
    for (final pile in stacks) {
      if (pile.isEmpty) continue;
      final top = pile.last;
      if (!top.isRevealed) {
        final r = top.copyWith(isRevealed: true);
        pile[pile.length - 1] = r;
        if (record) events!.add(CoinRevealed(r));
      }
    }
  }

  int _firstFusable(
    List<List<CoinState>> stacks,
    List<int> thresholds, {
    required int preferred,
  }) {
    if (_runLength(stacks[preferred]) >= thresholds[preferred]) {
      return preferred;
    }
    for (var i = 0; i < stacks.length; i++) {
      if (_runLength(stacks[i]) >= thresholds[i]) return i;
    }
    return -1;
  }

  void _thawAround(
    List<StackState> layout,
    List<List<CoinState>> stacks,
    int index,
    List<DomainEvent> events,
    bool record,
  ) {
    for (var i = index - 1; i <= index + 1; i++) {
      if (i < 0 || i >= stacks.length) continue;
      // Extra trays are never frost neighbours (rules v2).
      if (i != index && (layout[i].isAuxiliary || layout[index].isAuxiliary)) {
        continue;
      }
      final pile = stacks[i];
      for (var j = 0; j < pile.length; j++) {
        final c = pile[j];
        if (!c.isFrozen) continue;
        final t = c.copyWith(frost: c.frost - 1);
        pile[j] = t;
        if (record) {
          events.add(CoinThawed(coinId: c.id, remaining: t.frost));
        }
      }
    }
  }

  static int _runLength(List<CoinState> pile) {
    if (pile.isEmpty || !pile.last.isActive) return 0;
    final t = pile.last;
    var n = 0;
    for (var i = pile.length - 1; i >= 0; i--) {
      final c = pile[i];
      if (!c.isActive || !c.sameKindAs(t)) break;
      n++;
    }
    return n;
  }

  bool _coinsConserved(BoardState a, BoardState b) {
    // Coin "value" in tier-1 units is conserved except for sealed sets.
    int units(BoardState s) {
      var u = 0;
      for (final c in [
        for (final st in s.stacks) ...st.coins,
        for (var i = s.dealIndex; i < s.deals.length; i++) ...s.deals[i].coins,
      ]) {
        u += _pow(s.rules.mergeThreshold, c.tier - 1);
      }
      return u;
    }

    if (a.rules.fillToSeal) {
      // Sets vary in size: the progress records how many coins they held.
      final sealedCoins = b.progress.sealedCoins - a.progress.sealedCoins;
      return units(a) == units(b) + sealedCoins;
    }
    final sealedDelta = b.progress.sealed - a.progress.sealed;
    final sealedUnits =
        sealedDelta * _pow(a.rules.mergeThreshold, a.rules.maxTier);
    return units(a) == units(b) + sealedUnits;
  }

  static int _pow(int b, int e) {
    var r = 1;
    for (var i = 0; i < e; i++) {
      r *= b;
    }
    return r;
  }

  static int _min3(int a, int b, int c) {
    final m = a < b ? a : b;
    return m < c ? m : c;
  }
}

/// Status of the board after the latest committed transition.
enum BoardStatus { playable, completed, noLegalMoves }

extension BoardStatusX on RulesEngine {
  BoardStatus status(BoardState state, ObjectiveDefinition objective) {
    if (objective.isMet(state)) return BoardStatus.completed;
    return legalMoves(state).isEmpty
        ? BoardStatus.noLegalMoves
        : BoardStatus.playable;
  }
}
