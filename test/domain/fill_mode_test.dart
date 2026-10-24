import 'package:coin/domain/generator/level_generator.dart';
import 'package:coin/domain/model/board.dart';
import 'package:coin/domain/model/coin.dart';
import 'package:coin/domain/model/move.dart';
import 'package:coin/domain/model/objective.dart';
import 'package:coin/domain/rules/rules_engine.dart';
import 'package:coin/domain/solver/solver.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fill mode (rules v3): a tray seals when full of one kind; set size is
/// the tray's own height.
void main() {
  const engine = RulesEngine();
  var serial = 0;
  CoinState c(String f) => CoinState(id: 'c${serial++}', familyId: f);
  StackState st(String id, int cap, List<CoinState> coins) =>
      StackState(id: id, capacity: cap, coins: coins);
  const rules = RuleSet(mergeThreshold: 3, maxTier: 1, fillToSeal: true);

  test('a run equal to the tray height seals; a shorter one does not', () {
    final b = BoardState(
      rules: rules,
      stacks: [
        st('a', 3, [c('ruby'), c('ruby')]),
        st('b', 5, [c('jade'), c('ruby')]),
        st('c', 5, []),
      ],
    );
    expect(engine.invariantViolations(b), isEmpty);
    // 1 ruby onto the 2 in the 3-tray: full, seals.
    final r = engine.apply(b, const MoveCommand('b', 'a')).next;
    expect(r.stackById('a')!.coins, isEmpty);
    expect(r.progress.sealed, 1);
    expect(r.progress.sealedCoins, 3);
    // 2 rubies into the 5-tray: no seal.
    final r2 = engine
        .apply(
          engine.apply(b, const MoveCommand('b', 'c')).next,
          const MoveCommand('a', 'c'),
        )
        .next;
    expect(r2.stackById('c')!.coins.length, 3);
    expect(r2.progress.sealed, 0);
  });

  test(
    'a move fills the destination to its height, not to the merge count',
    () {
      final b = BoardState(
        rules: rules,
        stacks: [
          st('a', 6, [c('jade'), c('jade'), c('jade'), c('jade')]),
          st('b', 6, [c('jade')]),
        ],
      );
      final v = engine.validate(b, const MoveCommand('a', 'b'));
      expect(v.count, 4);
      final r = engine.apply(b, const MoveCommand('a', 'b')).next;
      expect(r.stackById('b')!.coins.length, 5);
    },
  );

  test('a full tray of one kind is an unsettled board', () {
    final b = BoardState(
      rules: rules,
      stacks: [
        st('a', 3, [c('jade'), c('jade'), c('jade')]),
        st('b', 4, []),
      ],
    );
    expect(engine.invariantViolations(b), contains('unsettled run in a'));
  });

  test('fill mode needs a single tier', () {
    final b = BoardState(
      rules: const RuleSet(mergeThreshold: 3, maxTier: 2, fillToSeal: true),
      stacks: [st('a', 3, []), st('b', 3, [])],
    );
    expect(engine.invariantViolations(b), isNotEmpty);
  });

  test('rules and progress round-trip through JSON', () {
    expect(RuleSet.fromJson(rules.toJson()), rules);
    const classic = RuleSet(mergeThreshold: 3, maxTier: 1);
    expect(RuleSet.fromJson(classic.toJson()).fillToSeal, isFalse);
    final p = ObjectiveProgress.empty.withSealed(5).withSealed(4);
    expect(ObjectiveProgress.fromJson(p.toJson()), p);
    expect(p.sealedCoins, 9);
  });

  test('solver clears a small fill board', () {
    final b = BoardState(
      rules: rules,
      stacks: [
        st('a', 3, [c('ruby'), c('jade'), c('jade')]),
        st('b', 4, [c('jade'), c('ruby'), c('ruby'), c('jade')]),
        st('c', 4, []),
      ],
    );
    final r = const Solver().solve(b, const ClearBoardObjective());
    expect(r.isSolved, isTrue);
    expect(
      const Solver().verifyPath(b, const ClearBoardObjective(), r.path),
      isTrue,
    );
  });

  test('generator: fill boards have one tray height and no sealed tray', () {
    const spec = GeneratorSpec(
      families: 4,
      mergeThreshold: 7,
      maxTier: 1,
      capacity: 7,
      stacks: 9,
      emptyStacks: 2,
      setsPerFamily: 1,
      extraSetFamilies: 2,
      deals: 2,
      dealSize: 5,
      fillCapacities: [7],
    );
    var found = 0;
    for (var seed = 1; seed <= 20; seed++) {
      final b = const LevelGenerator().candidate(spec, seed);
      if (b == null) continue;
      found++;
      expect(b.rules.fillToSeal, isTrue);
      expect(b.stacks.every((s) => s.capacity == 7), isTrue);
      expect(engine.invariantViolations(engine.settle(b)), isEmpty);
      // 4 families: two with 2 sets, two with 1: 6 sets of 7.
      final total = b.coinCount + b.deals.fold(0, (n, d) => n + d.coinCount);
      expect(total, 42);
    }
    expect(found, greaterThan(0));
  });
}
