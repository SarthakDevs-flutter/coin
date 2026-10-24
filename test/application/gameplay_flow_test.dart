import 'dart:io';

import 'package:coin/application/ports/board_presenter.dart';
import 'package:coin/application/ports/ports.dart';
import 'package:coin/application/providers.dart';
import 'package:coin/application/session/game_session.dart';
import 'package:coin/application/session/gameplay_controller.dart';
import 'package:coin/application/session/solver_runner.dart';
import 'package:coin/data/levels/level_repository.dart';
import 'package:coin/data/save/file_save_store.dart';
import 'package:coin/data/save/save_repository.dart';
import 'package:coin/domain/model/board.dart';
import 'package:coin/domain/progression/player_profile.dart';
import 'package:coin/infrastructure/ads/unconfigured_ads.dart';
import 'package:coin/infrastructure/audio/flame_audio_adapter.dart';
import 'package:coin/infrastructure/billing/unavailable_billing.dart';
import 'package:coin/infrastructure/crash_reporting/local_crash_reporter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coin/domain/model/move.dart';
import 'package:flutter_test/flutter_test.dart';

class FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

class RecordingAnalytics implements AnalyticsPort {
  final events = <AnalyticsEvent>[];
  @override
  void log(AnalyticsEvent event, [Map<String, Object> params = const {}]) =>
      events.add(event);
}

class NoHaptics implements HapticsPort {
  @override
  void play(HapticKind kind) {}
}

/// Presenter double: completes transitions immediately and records calls.
class FakePresenter implements BoardPresenter {
  final transitions = <SessionTransition>[];
  BoardState? shown;
  BoardHighlights highlights = BoardHighlights.none;
  final nudged = <String>[];

  @override
  void showBoard(BoardState state, {required bool animate}) => shown = state;
  @override
  Future<void> playTransition(SessionTransition t) {
    transitions.add(t);
    shown = t.to;
    return Future.value();
  }

  @override
  void setHighlights(BoardHighlights h) => highlights = h;
  @override
  void nudge(String stackId) => nudged.add(stackId);
  @override
  void fastForward() {}
}

Future<(ProviderContainer, MemorySaveStore, RecordingAnalytics)> boot({
  MemorySaveStore? store,
}) async {
  final s = store ?? MemorySaveStore();
  final analytics = RecordingAnalytics();
  final container = ProviderContainer(
    overrides: [
      servicesProvider.overrideWithValue(
        AppServices(
          saves: SaveRepository(s),
          levels: const LevelRepository(),
          bundle: FileBundle(),
          audio: const SilentAudio(),
          haptics: NoHaptics(),
          analytics: analytics,
          crash: LocalCrashReporter(),
          ads: UnconfiguredAds(),
          billing: UnavailableBilling(),
          solver: const InlineSolverRunner(),
        ),
      ),
    ],
  );
  await container.read(bootProvider.future);
  return (container, s, analytics);
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  test(
    'tutorial end to end: guided taps, undo step, win, reward once',
    () async {
      final (c, store, analytics) = await boot();
      final ctrl = c.read(gameplayProvider.notifier);
      final presenter = FakePresenter();
      final tutorial = c.read(packProvider).levels.first;
      ctrl
        ..open(tutorial.id)
        ..attach(presenter);
      expect(presenter.highlights.focus, {'s0'});

      // Wrong stack: rejected without mutation.
      ctrl.tapStack('s1');
      expect(c.read(gameplayProvider)!.session.board.moveCount, 0);

      ctrl
        ..tapStack('s0')
        ..tapStack('s2');
      expect(presenter.transitions, hasLength(1));
      ctrl.undo();
      ctrl
        ..tapStack('s0')
        ..tapStack('s2')
        ..tapStack('s1')
        ..tapStack('s0')
        ..tapStack('s1')
        ..tapStack('s2');
      await settle();
      final st = c.read(gameplayProvider)!;
      expect(st.session.phase, SessionPhase.completed);
      expect(st.win, isNotNull);
      expect(st.win!.granted, tutorial.reward);

      final profile = c.read(saveProvider).profile;
      expect(profile.gilt, tutorial.reward);
      expect(profile.tutorialDone, isTrue);
      expect(profile.count(InventoryItem.hint), 5);
      expect(c.read(saveProvider).activeSession, isNull);
      expect(analytics.events, contains(AnalyticsEvent.tutorialCompleted));

      // Replaying the level never pays twice.
      ctrl.restart();
      ctrl
        ..tapStack('s0')
        ..tapStack('s2')
        ..undo()
        ..tapStack('s0')
        ..tapStack('s2')
        ..tapStack('s1')
        ..tapStack('s0')
        ..tapStack('s1')
        ..tapStack('s2');
      await settle();
      expect(c.read(gameplayProvider)!.win!.alreadyClaimed, isTrue);
      expect(c.read(saveProvider).profile.gilt, tutorial.reward);

      // Persisted to disk: a fresh boot sees the same progress.
      await c.read(servicesProvider).saves.flush();
      final (c2, _, _) = await boot(store: store);
      expect(c2.read(saveProvider).profile.gilt, tutorial.reward);
      c.dispose();
      c2.dispose();
    },
  );

  test('resume after process death restores the exact board', () async {
    final (c, store, _) = await boot();
    final level = c.read(packProvider).levels[1];
    // Level 2 introduces a mechanic: taps are ignored until it is dismissed.
    final ctrl = c.read(gameplayProvider.notifier)
      ..open(level.id)
      ..dismissIntro();
    final move = level.proof!.solution.first;
    ctrl
      ..tapStack(move.from)
      ..tapStack(move.to);
    final board = c.read(gameplayProvider)!.session.board;
    await c.read(servicesProvider).saves.flush();
    c.dispose();

    final (c2, _, _) = await boot(store: store);
    c2.read(gameplayProvider.notifier).open(level.id);
    final restored = c2.read(gameplayProvider)!.session;
    expect(restored.board, board);
    expect(restored.canUndo, isTrue);
    c2.dispose();
  });

  test(
    'hint spends only when a move is found and highlights a legal move',
    () async {
      final (c, _, _) = await boot();
      final level = c.read(packProvider).levels[3];
      final ctrl = c.read(gameplayProvider.notifier)..open(level.id);
      final presenter = FakePresenter();
      ctrl.attach(presenter);
      final before = c.read(saveProvider).profile.count(InventoryItem.hint);
      await ctrl.useHint();
      final st = c.read(gameplayProvider)!;
      expect(st.hint, isNotNull);
      expect(st.session.legalMoves, contains(st.hint));
      expect(presenter.highlights.hint, st.hint);
      expect(
        c.read(saveProvider).profile.count(InventoryItem.hint),
        before - 1,
      );
      c.dispose();
    },
  );

  test(
    'stale hint result after the board changed is dropped and not charged',
    () async {
      final (c, _, _) = await boot();
      final level = c.read(packProvider).levels[3];
      final ctrl = c.read(gameplayProvider.notifier)..open(level.id);
      final before = c.read(saveProvider).profile.count(InventoryItem.hint);
      final pending = ctrl.useHint();
      // Any legal tap move changes the board while the hint is searching.
      final move = c
          .read(gameplayProvider)!
          .session
          .legalMoves
          .firstWhere((m) => m != MoveCommand.deal);
      ctrl
        ..tapStack(move.from)
        ..tapStack(move.to);
      await pending;
      expect(c.read(gameplayProvider)!.hint, isNull);
      expect(c.read(saveProvider).profile.count(InventoryItem.hint), before);
      c.dispose();
    },
  );

  test('illegal tap nudges and reports, never mutates', () async {
    final (c, _, _) = await boot();
    final level = c.read(packProvider).levels[1];
    final ctrl = c.read(gameplayProvider.notifier)..open(level.id);
    final presenter = FakePresenter();
    ctrl.attach(presenter);
    final s = c.read(gameplayProvider)!.session;
    // Find an illegal (source, destination) pair.
    final legal = s.legalMoves.toSet();
    String? src, dst;
    for (final a in s.board.stacks) {
      if (!s.liftable.contains(a.id)) continue;
      for (final b in s.board.stacks) {
        if (a.id != b.id &&
            !legal.any((m) => m.from == a.id && m.to == b.id) &&
            !s.liftable.contains(b.id)) {
          src = a.id;
          dst = b.id;
        }
      }
    }
    if (src == null) return; // board has no such pair
    final hash = s.board.stateHash;
    ctrl
      ..tapStack(src)
      ..tapStack(dst!);
    expect(c.read(gameplayProvider)!.session.board.stateHash, hash);
    expect(presenter.nudged, contains(dst));
    expect(c.read(gameplayProvider)!.message, isNotNull);
    c.dispose();
  });
}
