import 'dart:convert';

import 'package:coin/domain/model/board.dart';
import 'package:coin/domain/model/coin.dart';
import 'package:coin/domain/model/events.dart';
import 'package:coin/domain/model/move.dart';
import 'package:coin/domain/model/objective.dart';
import 'package:coin/domain/rules/rules_engine.dart';
import 'package:coin/domain/solver/solver.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_boards.dart';

const engine = RulesEngine();

CoinState c(String id, String f) => CoinState(id: id, familyId: f);

BoardState withDeals(BoardState b, List<DealBatch> deals) =>
    BoardState(stacks: b.stacks, rules: b.rules, deals: deals);

void main() {
  final base = board(['J J', 'R', ''], capacity: 4);
  final deals = [
    DealBatch([
      DealDrop(stackId: 's0', coins: [c('d0', 'jade')]),
      DealDrop(stackId: 's1', coins: [c('d1', 'ruby'), c('d2', 'ruby')]),
    ]),
  ];

  test(
    'deal is a legal move only while batches remain and trays have room',
    () {
      final b = withDeals(base, deals);
      expect(engine.legalMoves(b), contains(MoveCommand.deal));
      final r = engine.apply(b, MoveCommand.deal);
      expect(r.next.dealIndex, 1);
      expect(engine.validateDeal(r.next).rejection, MoveRejection.noDealsLeft);
      expect(r.events.whereType<CoinsDealt>(), hasLength(1));
    },
  );

  test('dealt coins resolve: jade completes a seal, rubies seal too', () {
    final r = engine.apply(withDeals(base, deals), MoveCommand.deal);
    expect(r.next.progress.sealed, 2);
    expect(r.next.coinCount, 0);
    expect(const ClearBoardObjective().isMet(r.next), isTrue);
  });

  test('clear board is not met while deals remain', () {
    final empty = withDeals(board(['', ''], capacity: 3), deals);
    expect(const ClearBoardObjective().isMet(empty), isFalse);
  });

  test('deal blocked when a target tray lacks room, and says which', () {
    final full = withDeals(board(['J J', 'R S R S', ''], capacity: 4), deals);
    expect(engine.validateDeal(full).rejection, MoveRejection.dealNoRoom);
    expect(engine.dealBlockedStacks(full), ['s1']);
    expect(engine.legalMoves(full), isNot(contains(MoveCommand.deal)));
  });

  test('solver plans moves around deals; json round-trips deal state', () {
    final b = withDeals(board(['J R', 'R J', ''], capacity: 4), [
      DealBatch([
        DealDrop(stackId: 's2', coins: [c('d0', 'jade')]),
      ]),
      DealBatch([
        DealDrop(stackId: 's2', coins: [c('d1', 'ruby')]),
      ]),
    ]);
    final r = const Solver().solve(b, const ClearBoardObjective());
    expect(r.status, SolveStatus.solved);
    expect(r.path, contains(MoveCommand.deal));
    expect(
      const Solver().verifyPath(b, const ClearBoardObjective(), r.path),
      isTrue,
    );
    final after = engine.apply(b, MoveCommand.deal).next;
    final round = BoardState.fromJson(
      (jsonDecode(jsonEncode(after.toJson())) as Map).cast(),
    );
    expect(round, after);
    expect(round.deals.length, 2);
  });
}
