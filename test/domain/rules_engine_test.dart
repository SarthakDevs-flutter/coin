import 'dart:convert';

import 'package:coin/core/seeded_random.dart';
import 'package:coin/domain/model/board.dart';
import 'package:coin/domain/model/events.dart';
import 'package:coin/domain/model/move.dart';
import 'package:coin/domain/model/objective.dart';
import 'package:coin/domain/rules/rules_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_boards.dart';

const engine = RulesEngine();

void main() {
  group('validation', () {
    test('rejects unknown, same, empty source', () {
      final b = board(['J', '']);
      expect(
        engine.validate(b, const MoveCommand('s0', 'x')).rejection,
        MoveRejection.unknownStack,
      );
      expect(
        engine.validate(b, const MoveCommand('s0', 's0')).rejection,
        MoveRejection.sameStack,
      );
      expect(
        engine.validate(b, const MoveCommand('s1', 's0')).rejection,
        MoveRejection.sourceEmpty,
      );
    });

    test('rejects mismatch and full destination', () {
      final b = board(['J', 'R', 'R J R J'], capacity: 4);
      expect(
        engine.validate(b, const MoveCommand('s0', 's1')).rejection,
        MoveRejection.mismatch,
      );
      expect(
        engine.validate(b, const MoveCommand('s0', 's2')).rejection,
        MoveRejection.destinationFull,
      );
    });

    test('frozen top cannot be lifted or covered', () {
      final b = board(['J*1', 'J', '']);
      expect(
        engine.validate(b, const MoveCommand('s0', 's2')).rejection,
        MoveRejection.sourceFrozen,
      );
      expect(
        engine.validate(b, const MoveCommand('s1', 's0')).rejection,
        MoveRejection.destinationFrozen,
      );
    });

    test('moves whole top run, bounded by space and threshold', () {
      final b = board(['R J J', 'J', ''], threshold: 4, capacity: 5);
      expect(engine.validate(b, const MoveCommand('s0', 's2')).count, 2);
      expect(engine.validate(b, const MoveCommand('s0', 's1')).count, 2);
      final tight = board(['R J J', 'J J', ''], threshold: 3, capacity: 5);
      // Only one more jade is needed to reach the threshold.
      expect(engine.validate(tight, const MoveCommand('s0', 's1')).count, 1);
    });
  });

  group('apply', () {
    test('illegal apply throws and leaves state untouched', () {
      final b = board(['J', 'R']);
      final before = jsonEncode(b.toJson());
      expect(
        () => engine.apply(b, const MoveCommand('s0', 's1')),
        throwsArgumentError,
      );
      expect(jsonEncode(b.toJson()), before);
    });

    test('reaching threshold at maxTier seals the set', () {
      final b = board(['R J', 'J J', '']);
      final r = engine.apply(b, const MoveCommand('s0', 's1'));
      expect(r.next.stacks[1].coins, isEmpty);
      expect(r.next.progress.sealed, 1);
      expect(r.events.whereType<CoinsFused>().single.isSeal, isTrue);
      expect(r.next.moveCount, 1);
    });

    test('below maxTier fuses into next tier with deterministic id', () {
      final b = board(['J', 'J J', ''], maxTier: 2);
      final r = engine.apply(b, const MoveCommand('s0', 's1'));
      final top = r.next.stacks[1].coins.single;
      expect(top.tier, 2);
      expect(top.id, 'f0');
      expect(r.next.nextCoinSerial, 1);
      expect(r.next.progress.forgedOfTier(2), 1);
    });

    test('chain: forged coin completes a higher-tier set', () {
      final b = board(['J', 'J2 J2 J J', ''], maxTier: 2, capacity: 5);
      final r = engine.apply(b, const MoveCommand('s0', 's1'));
      final fused = r.events.whereType<CoinsFused>().toList();
      expect(fused, hasLength(2));
      expect(fused.first.produced!.tier, 2);
      expect(fused.last.isSeal, isTrue);
      expect(r.next.stacks[1].coins, isEmpty);
    });

    test('veiled coin is revealed when uncovered and does not join runs', () {
      final b = board(['J? R', 'R R', '']);
      expect(b.stacks[0].coins.first.isRevealed, isFalse);
      final r = engine.apply(b, const MoveCommand('s0', 's1'));
      expect(r.next.stacks[0].top!.isRevealed, isTrue);
      expect(r.events.whereType<CoinRevealed>(), hasLength(1));
    });

    test('fuse thaws frost in own and neighbouring stacks only', () {
      final b = board(['J*1', 'R', 'R R', 'S*1', 'A*1'], capacity: 4);
      final r = engine.apply(b, const MoveCommand('s1', 's2'));
      expect(r.next.stacks[0].coins.single.isFrozen, isTrue); // two away
      expect(r.next.stacks[3].coins.single.isFrozen, isFalse);
      expect(r.next.stacks[4].coins.single.isFrozen, isTrue);
    });

    test('thaw can trigger a follow-up fuse elsewhere', () {
      // s2 = J J*1 J : run is 1 until thawed, then 3 → seals.
      final b = board(['R', 'R R', 'J J*1 J', ''], capacity: 4);
      final r = engine.apply(b, const MoveCommand('s0', 's1'));
      expect(r.next.stacks[2].coins, isEmpty);
      expect(r.next.progress.sealed, 2);
    });

    test('objective completion emits one event', () {
      final b = board(['J J', 'J']);
      final r = engine.apply(
        b,
        const MoveCommand('s1', 's0'),
        objective: const ClearBoardObjective(),
      );
      expect(r.events.whereType<ObjectiveCompleted>(), hasLength(1));
      expect(
        engine.status(r.next, const ClearBoardObjective()),
        BoardStatus.completed,
      );
    });

    test('no legal moves is detected', () {
      final b = board(['J R J R', 'R J R J'], capacity: 4);
      expect(engine.legalMoves(b), isEmpty);
      expect(
        engine.status(b, const ClearBoardObjective()),
        BoardStatus.noLegalMoves,
      );
    });
  });

  group('properties (random walks)', () {
    test('accepted moves preserve invariants; serialization round-trips', () {
      for (var seed = 1; seed <= 60; seed++) {
        final rng = SeededRandom(seed);
        var s = board(
          ['J R S J', 'R S J', 'S R J R', 'J? S R', 'S2 J', '', ''],
          capacity: 5,
          threshold: 3,
          maxTier: 2,
        );
        s = engine.settle(s);
        for (var step = 0; step < 40; step++) {
          final moves = engine.legalMoves(s);
          if (moves.isEmpty) break;
          for (final m in moves) {
            expect(engine.isLegal(s, m), isTrue);
          }
          final m = moves[rng.nextInt(moves.length)];
          final r = engine.apply(s, m);
          expect(engine.invariantViolations(r.next), isEmpty);
          expect(r.previous, same(s));
          final round = BoardState.fromJson(
            (jsonDecode(jsonEncode(r.next.toJson())) as Map).cast(),
          );
          expect(round, r.next);
          s = r.next;
        }
      }
    });
  });
}
