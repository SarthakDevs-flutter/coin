import 'package:coin/application/ports/ports.dart';
import 'package:coin/application/session/game_session.dart';
import 'package:coin/domain/model/level.dart';
import 'package:coin/domain/model/move.dart';
import 'package:coin/domain/model/objective.dart';
import 'package:coin/game/coin_atelier_game.dart';
import 'package:coin/game/components/coin_component.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/test_boards.dart';

final class _SilentAudio implements AudioPort {
  @override
  Future<void> preload() async {}
  @override
  void play(Sfx sfx) {}
  @override
  void playLanding(int order) {}
  @override
  void setMusicEnabled(bool enabled) {}
  @override
  void setSfxEnabled(bool enabled) {}
  @override
  void pauseAll() {}
  @override
  void resumeAll() {}
}

LevelDefinition _level() => LevelDefinition(
  id: 't-anim',
  number: 1,
  chapter: 1,
  version: 1,
  difficulty: 'easy',
  initialState: board(['J R R', 'R J J', ''], capacity: 3),
  objective: const ClearBoardObjective(),
  reward: 10,
  parMoves: 3,
);

Future<CoinAtelierGame> _mount(WidgetTester tester) async {
  final game = CoinAtelierGame(onStackTap: (_) {}, audio: _SilentAudio());
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(width: 400, height: 700, child: GameWidget(game: game)),
      ),
    ),
  );
  // Let the game load and lay out.
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  expect(game.isLoaded, isTrue);
  return game;
}

Map<String, Vector2> _positions(CoinAtelierGame game) => {
  for (final c in game.children.whereType<CoinComponent>())
    c.coin.id: c.position.clone(),
};

Future<void> _pumpSeconds(WidgetTester tester, double seconds) async {
  final frames = (seconds * 60).ceil();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('a move committed mid-flight glides instead of snapping', (
    tester,
  ) async {
    final game = await _mount(tester);
    final session = GameSession(level: _level());
    game.showBoard(session.board, animate: false);
    await _pumpSeconds(tester, 0.1);

    final first = session.submitMove(const MoveCommand('s0', 's2'));
    final settled1 = game.playTransition(first.transition!);
    await _pumpSeconds(tester, 0.12);

    final flying = game.children.whereType<CoinComponent>().where(
      (c) => c.airborne,
    );
    expect(flying, isNotEmpty, reason: 'the run should be in the air');
    final before = _positions(game);

    // Second move lands while the first is still flying.
    final second = session.submitMove(const MoveCommand('s1', 's0'));
    final settled2 = game.playTransition(second.transition!);
    expect(settled1, completes);

    // Nothing teleports on the interrupt frame...
    final after = _positions(game);
    for (final e in before.entries) {
      expect(
        after[e.key]!.distanceTo(e.value),
        lessThan(0.001),
        reason: 'coin ${e.key} jumped on interrupt',
      );
    }
    // ...and no coin keeps a flight pose.
    for (final c in game.children.whereType<CoinComponent>()) {
      expect(c.airborne, isFalse);
      expect(c.roll, 0);
    }

    await _pumpSeconds(tester, 2.5);
    await expectLater(settled2, completes);

    final coins = game.children.whereType<CoinComponent>().toList();
    expect(coins, hasLength(session.board.coinCount));
    expect(coins.any((c) => c.isAnimating), isFalse);
    expect(coins.any((c) => c.removing), isFalse);

    // Every coin rests exactly where a cold rebuild would put it.
    final rested = _positions(game);
    game.showBoard(session.board, animate: false);
    await _pumpSeconds(tester, 0.05);
    final snapped = _positions(game);
    for (final e in rested.entries) {
      expect(
        snapped[e.key]!.distanceTo(e.value),
        lessThan(0.5),
        reason: 'coin ${e.key} did not settle in its slot',
      );
    }
  });

  testWidgets('a full flight lands every coin flat in its slot', (
    tester,
  ) async {
    final game = await _mount(tester);
    final session = GameSession(level: _level());
    game.showBoard(session.board, animate: false);
    await _pumpSeconds(tester, 0.1);

    final out = session.submitMove(const MoveCommand('s0', 's2'));
    final settled = game.playTransition(out.transition!);
    await _pumpSeconds(tester, 2);
    await expectLater(settled, completes);

    final rested = _positions(game);
    game.showBoard(session.board, animate: false);
    await _pumpSeconds(tester, 0.05);
    final snapped = _positions(game);
    for (final e in rested.entries) {
      expect(snapped[e.key]!.distanceTo(e.value), lessThan(0.5));
    }
    for (final c in game.children.whereType<CoinComponent>()) {
      expect(c.airborne, isFalse);
      expect(c.squash, 1);
      expect(c.opacity, 1);
    }
  });
}
