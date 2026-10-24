import 'package:coin/application/session/game_session.dart';
import 'package:coin/domain/economy/economy.dart';
import 'package:coin/domain/model/level.dart';
import 'package:coin/domain/model/move.dart';
import 'package:coin/domain/model/objective.dart';
import 'package:coin/domain/progression/player_profile.dart';
import 'package:coin/domain/rules/rules_engine.dart';
import 'package:coin/domain/solver/solver.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_boards.dart';

final now = DateTime.utc(2026, 10, 24);

PlayerProfile withCompleted(int n, {int gilt = 1000}) {
  var p = PlayerProfile.fresh().copyWith(gilt: gilt);
  for (var i = 0; i < n; i++) {
    p = p.copyWith(
      completions: {
        ...p.completions,
        'l$i': CompletionRecord(
          levelVersion: 1,
          bestMoves: 1,
          firstCompletedAt: now,
        ),
      },
    );
  }
  return p;
}

LevelDefinition lvl(List<String> stacks) => LevelDefinition(
  id: 'w-1',
  number: 5,
  chapter: 1,
  version: 1,
  difficulty: 'easy',
  initialState: board(stacks, capacity: 4),
  objective: const ClearBoardObjective(),
  reward: 1,
  parMoves: 1,
);

void main() {
  group('unlock rules', () {
    test('slots unlock in order, after the level gate, for gilt', () {
      final first = WorkshopCatalog.slots.first;
      expect(
        Economy.unlockWorkshopSlot(
          withCompleted(first.afterLevel - 1),
          0,
          now: now,
        ).error,
        EconomyError.notYet,
      );
      expect(
        Economy.unlockWorkshopSlot(withCompleted(40), 1, now: now).error,
        EconomyError.notYet,
      );
      expect(
        Economy.unlockWorkshopSlot(
          withCompleted(40, gilt: 0),
          0,
          now: now,
        ).error,
        EconomyError.insufficientFunds,
      );
      final r = Economy.unlockWorkshopSlot(withCompleted(40), 0, now: now);
      expect(r.profile.workshopSlots, 1);
      expect(r.profile.gilt, 1000 - first.cost);
      expect(
        Economy.unlockWorkshopSlot(r.profile, 0, now: now).error,
        EconomyError.alreadyOwned,
      );
      expect(PlayerProfile.fromJson(r.profile.toJson()).workshopSlots, 1);
    });
  });

  group('board', () {
    const engine = RulesEngine();

    test('workshop trays are never frost neighbours', () {
      // w0 sits right after s2. A seal inside w0 must not thaw s2.
      var b = engine.addWorkshopStack(
        board(['J J', 'J', 'S*1'], capacity: 4),
        0,
      );
      b = engine.apply(b, const MoveCommand('s0', 'w0')).next;
      final r = engine.apply(b, const MoveCommand('s1', 'w0'));
      expect(r.next.progress.sealed, 1, reason: 'the fuse happened in w0');
      expect(r.next.stackById('s2')!.coins.single.isFrozen, isTrue);
    });

    test('extra trays never make a solvable level unsolvable', () {
      final level = lvl(['J R J', 'R J R', '']);
      final base = engine.settle(level.initialState);
      final withSlots = engine.addWorkshopStack(
        engine.addWorkshopStack(base, 0),
        1,
      );
      const solver = Solver();
      expect(solver.solve(base, level.objective).isSolved, isTrue);
      expect(solver.solve(withSlots, level.objective).isSolved, isTrue);
    });

    test('session: unlocking mid-level keeps undo history and the tray', () {
      final s = GameSession(level: lvl(['J R', 'R J', '']), workshopSlots: 1);
      expect(s.board.stackById('w0'), isNotNull);
      s.submitMove(const MoveCommand('s0', 's2'));
      final out = s.syncWorkshop(2);
      expect(out.transition?.kind, TransitionKind.workshop);
      expect(s.board.stackById('w1'), isNotNull);
      s.undo();
      expect(s.board.stackById('w1'), isNotNull, reason: 'undo keeps upgrades');
      s.restart();
      expect(
        s.board.stackById('w1'),
        isNotNull,
        reason: 'restart keeps upgrades',
      );
    });
  });
}
