import 'package:coin/application/ports/ports.dart';
import 'package:coin/application/providers.dart';
import 'package:coin/application/review/review_policy.dart';
import 'package:coin/application/session/gameplay_controller.dart';
import 'package:coin/application/state/settings.dart';
import 'package:coin/domain/progression/player_profile.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gameplay_flow_test.dart' show FakePresenter, boot, settle;

void main() {
  test('lesson logs each step and an early exit as abandoned', () async {
    final (c, _, analytics) = await boot();
    final ctrl = c.read(gameplayProvider.notifier);
    final lesson = c.read(packProvider).levels.first;
    ctrl
      ..open(lesson.id)
      ..attach(FakePresenter())
      ..tapStack('s0')
      ..tapStack('s2');
    expect(
      analytics.events.where((e) => e == AnalyticsEvent.tutorialStep),
      hasLength(1),
    );
    ctrl.leave();
    expect(analytics.events, contains(AnalyticsEvent.tutorialAbandoned));
    // No coach tips or nudges inside the lesson.
    expect(c.read(gameplayProvider)!.coach, isNull);
    c.dispose();
  });

  test('hint tip waits for the intro card, then shows once', () async {
    final (c, _, analytics) = await boot();
    await c
        .read(saveProvider.notifier)
        .updateProfile(
          (p) => p.copyWith(inventory: {...p.inventory, InventoryItem.hint: 5}),
        );
    final level2 = c.read(packProvider).levels[1];
    final ctrl = c.read(gameplayProvider.notifier)..open(level2.id);
    var st = c.read(gameplayProvider)!;
    expect(st.intro, isNotNull);
    expect(st.coach, isNull);

    ctrl.dismissIntro();
    st = c.read(gameplayProvider)!;
    expect(st.coach, 'coach_hint');
    expect(analytics.events, contains(AnalyticsEvent.coachTipShown));

    ctrl.dismissCoach();
    expect(c.read(gameplayProvider)!.coach, isNull);
    await settle();
    expect(
      c.read(saveProvider).profile.seenIntroductions,
      contains('coach_hint'),
    );

    // Reopening never repeats it.
    ctrl.open(level2.id);
    expect(c.read(gameplayProvider)!.coach, isNull);
    c.dispose();
  });

  test('idle nudge shows a legal move for free on early levels', () async {
    final (c, _, analytics) = await boot();
    final level2 = c.read(packProvider).levels[1];
    final ctrl = c.read(gameplayProvider.notifier)
      ..open(level2.id)
      ..dismissIntro();
    final presenter = FakePresenter();
    ctrl.attach(presenter);
    final hints = c.read(saveProvider).profile.count(InventoryItem.hint);

    await ctrl.debugIdleNudge();
    final st = c.read(gameplayProvider)!;
    expect(st.hint, isNotNull);
    expect(st.session.legalMoves, contains(st.hint));
    expect(presenter.highlights.hint, st.hint);
    expect(c.read(saveProvider).profile.count(InventoryItem.hint), hints);
    expect(analytics.events, contains(AnalyticsEvent.idleNudgeShown));
    c.dispose();
  });

  test('no idle nudge past the early levels', () async {
    final (c, _, _) = await boot();
    final level = c
        .read(packProvider)
        .levels
        .firstWhere((l) => l.number == GameplayController.lastNudgeLevel + 1);
    final ctrl = c.read(gameplayProvider.notifier)..open(level.id);
    if (c.read(gameplayProvider)!.intro != null) ctrl.dismissIntro();
    await ctrl.debugIdleNudge();
    expect(c.read(gameplayProvider)!.hint, isNull);
    c.dispose();
  });

  group('review policy', () {
    const policy = ReviewPolicy();
    final now = DateTime(2026, 10, 26);

    Future<bool> ask(
      int number, {
      bool firstClear = true,
      bool clean = true,
      List<DateTime> history = const [],
    }) async {
      final (c, _, _) = await boot();
      final level = c
          .read(packProvider)
          .levels
          .firstWhere((l) => l.number == number);
      c.dispose();
      return policy.shouldRequest(
        level: level,
        firstClear: firstClear,
        cleanAttempt: clean,
        history: history,
        now: now,
      );
    }

    test('asks only on a clean first clear of a milestone', () async {
      expect(await ask(12), isTrue);
      expect(await ask(13), isFalse);
      expect(await ask(12, firstClear: false), isFalse);
      expect(await ask(12, clean: false), isFalse);
      expect(await ask(1), isFalse);
    });

    test('respects the gap and the yearly cap', () async {
      final recent = now.subtract(const Duration(days: 30));
      expect(await ask(45, history: [recent]), isFalse);
      final old = [
        for (final d in [130, 260, 360]) now.subtract(Duration(days: d)),
      ];
      expect(await ask(45, history: old), isFalse);
      expect(await ask(45, history: old.sublist(0, 2)), isTrue);
    });
  });

  test('settings keep the privacy answer and review history', () {
    final at = DateTime.fromMillisecondsSinceEpoch(1700000000000);
    final s = const GameSettings().copyWith(
      privacyAsked: true,
      reviewRequests: [at],
    );
    final back = GameSettings.fromJson(s.toJson());
    expect(back.privacyAsked, isTrue);
    expect(back.reviewRequests, [at]);
    expect(GameSettings.fromJson(const {}).privacyAsked, isFalse);
  });
}
