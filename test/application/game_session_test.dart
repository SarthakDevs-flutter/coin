import 'dart:convert';

import 'package:coin/application/session/game_session.dart';
import 'package:coin/domain/model/level.dart';
import 'package:coin/domain/model/move.dart';
import 'package:coin/domain/model/objective.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/test_boards.dart';

LevelDefinition level({
  List<TutorialStep> tutorial = const [],
  List<String>? stacks,
}) => LevelDefinition(
  id: 't-1',
  number: 1,
  chapter: 1,
  version: 1,
  difficulty: 'easy',
  initialState: board(stacks ?? ['J R R', 'R J J', ''], capacity: 3),
  objective: const ClearBoardObjective(),
  reward: 10,
  parMoves: 3,
  tutorial: tutorial,
);

void main() {
  test('tap source then destination commits one move', () {
    final s = GameSession(level: level());
    expect(s.tapStack('s0').selectionChanged, isTrue);
    expect(s.phase, SessionPhase.sourceSelected);
    expect(s.legalTargets, contains('s2'));
    final out = s.tapStack('s2');
    expect(out.transition, isNotNull);
    expect(s.board.moveCount, 1);
    expect(s.selected, isNull);
  });

  test('illegal destination never mutates state', () {
    final s = GameSession(level: level(stacks: ['J R', 'R', 'S S']));
    s.tapStack('s0');
    final before = jsonEncode(s.board.toJson());
    final out = s.tapStack('s2');
    expect(out.rejection, CommandRejection.illegalMove);
    expect(jsonEncode(s.board.toJson()), before);
    expect(s.canUndo, isFalse);
  });

  test('tapping another liftable stack switches selection', () {
    final s = GameSession(level: level());
    s.tapStack('s0');
    final out = s.tapStack('s1');
    expect(out.selectionChanged, isTrue);
    expect(s.selected, 's1');
  });

  test('undo restores the exact previous board; restart restores initial', () {
    final s = GameSession(level: level());
    final initial = s.board;
    s.submitMove(const MoveCommand('s0', 's2'));
    final afterOne = s.board;
    s.submitMove(const MoveCommand('s1', 's0'));
    s.undo();
    expect(s.board, afterOne);
    s.undo();
    expect(s.board, initial);
    expect(s.undo().rejection, CommandRejection.nothingToUndo);
    s.submitMove(const MoveCommand('s0', 's2'));
    s.restart();
    expect(s.board, initial);
    expect(s.canUndo, isFalse);
  });

  test('completion is terminal and blocks further commands', () {
    final s = GameSession(level: level());
    s.submitMove(const MoveCommand('s0', 's2'));
    s.submitMove(const MoveCommand('s1', 's0'));
    s.submitMove(const MoveCommand('s1', 's2'));
    expect(s.phase, SessionPhase.completed);
    expect(s.tapStack('s0').rejection, CommandRejection.sessionOver);
    expect(s.undo().rejection, CommandRejection.sessionOver);
  });

  test('bonus tray clears undo history and can be used once', () {
    final s = GameSession(level: level());
    s.submitMove(const MoveCommand('s0', 's2'));
    expect(s.addBonusTray().transition, isNotNull);
    expect(s.board.stacks.last.isBonus, isTrue);
    expect(s.canUndo, isFalse);
    expect(s.addBonusTray().rejection, CommandRejection.bonusAlreadyUsed);
  });

  test('blocked phase is reported only when no legal move exists', () {
    final s = GameSession(level: level(stacks: ['J R J', 'R J R']));
    expect(s.phase, SessionPhase.blocked);
  });

  test('tutorial enforces scripted steps including undo', () {
    final s = GameSession(
      level: level(
        tutorial: const [
          TutorialStep(messageKey: 'a', move: MoveCommand('s0', 's2')),
          TutorialStep(messageKey: 'b', expectUndo: true),
          TutorialStep(messageKey: 'c', move: MoveCommand('s0', 's2')),
        ],
      ),
    );
    expect(s.tapStack('s1').rejection, CommandRejection.followTutorial);
    expect(s.undo().rejection, CommandRejection.followTutorial);
    s.tapStack('s0');
    s.tapStack('s2');
    expect(s.tutorialStep!.messageKey, 'b');
    expect(s.tapStack('s0').rejection, CommandRejection.followTutorial);
    expect(s.undo().transition, isNotNull);
    expect(s.tutorialStep!.messageKey, 'c');
  });

  test(
    'snapshot round-trips; version mismatch yields null for free restart',
    () {
      final s = GameSession(level: level());
      s.submitMove(const MoveCommand('s0', 's2'));
      final json = (jsonDecode(jsonEncode(s.toJson())) as Map)
          .cast<String, Object?>();
      final restored = GameSession.fromJson(json, level())!;
      expect(restored.board, s.board);
      expect(restored.history.length, 1);
      final v2 = LevelDefinition(
        id: 't-1',
        number: 1,
        chapter: 1,
        version: 2,
        difficulty: 'easy',
        initialState: board(['J'], capacity: 3),
        objective: const ClearBoardObjective(),
        reward: 1,
        parMoves: 1,
      );
      expect(GameSession.fromJson(json, v2), isNull);
    },
  );

  test('revision changes on every commit (stale async results detectable)', () {
    final s = GameSession(level: level());
    final r0 = s.revision;
    s.submitMove(const MoveCommand('s0', 's2'));
    expect(s.revision, greaterThan(r0));
  });
}
