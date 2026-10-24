import 'dart:io';

import 'package:coin/data/levels/level_repository.dart';
import 'package:coin/domain/model/families.dart';
import 'package:coin/domain/rules/level_validator.dart';
import 'package:coin/domain/rules/rules_engine.dart';
import 'package:coin/domain/solver/solver.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression gate over the shipped campaign (features-and-flows.md §8).
void main() {
  final loaded = LevelRepository.parse(
    File('assets/levels/campaign.json').readAsStringSync(),
  );
  final pack = loaded.pack;

  test('no level is rejected on device', () {
    expect(loaded.rejectedIds, isEmpty);
    expect(pack.levels.length, 300);
  });

  test('campaign shape: 4 short teaching chapters, then 13 of 20', () {
    expect(pack.chapters, List.generate(17, (i) => i + 1));
    for (var c = 1; c <= 4; c++) {
      expect(pack.chapter(c).length, 10, reason: 'chapter $c');
    }
    for (var c = 5; c <= 17; c++) {
      final levels = pack.chapter(c);
      expect(levels.length, 20, reason: 'chapter $c');
      // A super-hard level closes each half of the chapter.
      expect(levels[9].difficulty, 'expert', reason: 'chapter $c');
      expect(levels[19].difficulty, 'expert', reason: 'chapter $c');
    }
    final numbers = [for (final l in pack.levels) l.number];
    expect(numbers, List.generate(300, (i) => i + 1));
  });

  test('boards grow level by level: trays and tray height never shrink', () {
    final long = pack.levels.where((l) => l.chapter >= 5).toList();
    for (var i = 1; i < long.length; i++) {
      final a = long[i - 1].initialState, b = long[i].initialState;
      expect(
        b.stacks.length,
        greaterThanOrEqualTo(a.stacks.length),
        reason: long[i].id,
      );
      expect(
        b.stacks.first.capacity,
        greaterThanOrEqualTo(a.stacks.first.capacity),
        reason: long[i].id,
      );
    }
    int coins(int i) {
      final b = long[i].initialState;
      return b.coinCount + b.deals.fold(0, (n, d) => n + d.coinCount);
    }

    // Coins come in whole sets, so allow small dips, but the trend climbs.
    expect(coins(long.length - 1), greaterThan(coins(0) * 3));
  });

  test('hard levels pay more than the easy levels of their chapter', () {
    for (var c = 5; c <= 17; c++) {
      final levels = pack.chapter(c);
      final easy = levels.firstWhere((l) => l.difficulty == 'easy').reward;
      for (final l in levels.where((l) => l.difficulty == 'expert')) {
        expect(l.reward, greaterThan(easy), reason: l.id);
      }
    }
  });

  test('every level has a verified solution proof', () {
    for (final l in pack.levels) {
      expect(const LevelValidator().validate(l), isEmpty, reason: l.id);
    }
  });

  test('no false no-moves: every state on each proof path has legal moves', () {
    const engine = RulesEngine();
    for (final l in pack.levels) {
      var s = engine.settle(l.initialState);
      for (final m in l.proof!.solution) {
        expect(
          engine.legalMoves(s),
          isNotEmpty,
          reason: '${l.id} @${s.moveCount}',
        );
        expect(engine.legalMoves(s), contains(m));
        s = engine.apply(s, m).next;
      }
      expect(l.objective.isMet(s), isTrue, reason: l.id);
    }
  });

  test('restart determinism: settling the same level twice is identical', () {
    const engine = RulesEngine();
    for (final l in pack.levels) {
      expect(engine.settle(l.initialState), engine.settle(l.initialState));
    }
  });

  test('mechanics are introduced one at a time, tutorial first', () {
    expect(pack.levels.first.isTutorial, isTrue);
    final intros = [
      for (final l in pack.levels)
        if (l.introduces != null) l.introduces,
    ];
    expect(intros, ['basics', 'fill', 'deal', 'forge', 'hidden', 'frost']);
    for (final l in pack.levels) {
      for (final s in l.initialState.stacks) {
        for (final c in s.coins) {
          expect(CoinFamilies.isKnown(c.familyId), isTrue);
        }
      }
    }
  });

  test('solver independently re-solves a sample of levels', () {
    for (final l in pack.levels.where((l) => l.number % 5 == 0)) {
      // Same budget class the generator used: big boards are only shipped
      // when the solver clears them quickly.
      final r = const Solver().solve(
        const RulesEngine().settle(l.initialState),
        l.objective,
        maxNodes: (l.proof!.nodesExpanded * 2).clamp(5000, 400000),
      );
      expect(r.status, SolveStatus.solved, reason: l.id);
    }
  });
}
