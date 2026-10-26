import 'package:coin/application/ads/ad_policy.dart';
import 'package:coin/domain/progression/player_profile.dart';
import 'package:flutter_test/flutter_test.dart';

PlayerProfile veteran({int levels = 10, bool removeAds = false}) =>
    PlayerProfile.fresh().copyWith(
      tutorialDone: true,
      removeAds: removeAds,
      completions: {
        for (var i = 0; i < levels; i++)
          'l$i': CompletionRecord(
            levelVersion: 1,
            bestMoves: 5,
            firstCompletedAt: DateTime(2026),
          ),
      },
    );

void main() {
  test('interruptions wait for the lesson and stop with Remove Ads', () {
    expect(interruptionsAllowed(PlayerProfile.fresh()), isFalse);
    expect(interruptionsAllowed(veteran()), isTrue);
    expect(interruptionsAllowed(veteran(removeAds: true)), isFalse);
  });

  group('app-open policy', () {
    const policy = AppOpenPolicy();
    bool show(
      PlayerProfile p, {
      Duration away = const Duration(minutes: 5),
      Duration? since,
      bool inLevel = false,
      int shown = 0,
    }) => policy.shouldShow(
      p,
      timeAway: away,
      sinceLastFullScreen: since,
      inLevel: inLevel,
      shownThisSession: shown,
    );

    test('shows on a warm return for a regular player', () {
      expect(show(veteran()), isTrue);
    });

    test('never for new players, Remove Ads, or over a level', () {
      expect(show(veteran(levels: 2)), isFalse);
      expect(show(veteran(removeAds: true)), isFalse);
      expect(show(veteran(), inLevel: true), isFalse);
    });

    test('needs a real break and spacing from the last full-screen ad', () {
      expect(show(veteran(), away: const Duration(seconds: 5)), isFalse);
      expect(show(veteran(), since: const Duration(minutes: 1)), isFalse);
      expect(show(veteran(), since: const Duration(minutes: 10)), isTrue);
    });

    test('caps per session', () {
      expect(show(veteran(), shown: 3), isFalse);
    });
  });
}
