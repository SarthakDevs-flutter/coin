import 'package:coin/core/seeded_random.dart';
import 'package:coin/domain/generator/level_generator.dart';
import 'package:coin/domain/model/objective.dart';
import 'package:coin/domain/rules/rules_engine.dart';
import 'package:coin/domain/solver/solver.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_boards.dart';

const solver = Solver();
const clear = ClearBoardObjective();

void main() {
  test('solves a small board and the path verifies', () {
    final b = board(['J R R', 'R J J', ''], capacity: 3);
    final r = solver.solve(b, clear);
    expect(r.status, SolveStatus.solved);
    expect(solver.verifyPath(b, clear, r.path), isTrue);
  });

  test('proves a dead board unsolvable', () {
    final b = board(['J R J R', 'R J R J'], capacity: 4);
    expect(solver.solve(b, clear).status, SolveStatus.unsolvedProven);
  });

  test('budget exhaustion is reported as unknown, never unsolvable', () {
    final b = board(
      ['J R S A', 'R S A J', 'S A J R', 'A J R S', '', ''],
      capacity: 5,
      threshold: 4,
    );
    final r = solver.solve(b, clear, maxNodes: 1);
    expect(r.status, isNot(SolveStatus.unsolvedProven));
  });

  test('solver moves are all accepted by the rules engine', () {
    const engine = RulesEngine();
    const gen = LevelGenerator();
    var checked = 0;
    for (var seed = 1; checked < 8 && seed < 200; seed++) {
      final b = gen.candidate(
        const GeneratorSpec(
          families: 3,
          mergeThreshold: 3,
          maxTier: 1,
          capacity: 4,
          stacks: 5,
          emptyStacks: 1,
        ),
        seed,
      );
      if (b == null) continue;
      final r = solver.solve(engine.settle(b), clear);
      if (!r.isSolved) continue;
      var s = engine.settle(b);
      for (final m in r.path) {
        expect(engine.isLegal(s, m), isTrue);
        s = engine.apply(s, m).next;
      }
      expect(clear.isMet(s), isTrue);
      checked++;
    }
    expect(checked, greaterThan(0));
  });

  test('seeded random is stable across runs', () {
    final a = SeededRandom(42);
    final b = SeededRandom(42);
    final seqA = [for (var i = 0; i < 8; i++) a.nextUint32()];
    final seqB = [for (var i = 0; i < 8; i++) b.nextUint32()];
    expect(seqA, seqB);
    expect(seqA.toSet().length, 8);
    expect(seqA.every((v) => v >= 0 && v <= 0xFFFFFFFF), isTrue);
  });
}
