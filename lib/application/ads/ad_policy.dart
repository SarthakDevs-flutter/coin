import '../../domain/progression/player_profile.dart';

/// Banners, interstitials and app-open ads interrupt; rewarded ads are
/// chosen. Interruptions wait until the lesson is done and stop for good
/// once Remove Ads is owned.
bool interruptionsAllowed(PlayerProfile p) => !p.removeAds && p.tutorialDone;

/// Conservative interstitial rules (design.md §9). Interstitials are only ever
/// considered after the player taps Next on the win screen.
final class InterstitialPolicy {
  const InterstitialPolicy({
    this.minCompletedLevels = 3,
    this.levelsBetween = 4,
    this.maxPerSession = 2,
  });

  final int minCompletedLevels;
  final int levelsBetween;
  final int maxPerSession;

  bool shouldShow(PlayerProfile p, {required int shownThisSession}) =>
      interruptionsAllowed(p) &&
      p.completions.length >= minCompletedLevels &&
      p.levelsCompletedSinceInterstitial >= levelsBetween &&
      shownThisSession < maxPerSession;
}

/// App-open ads only on a warm return after a real break, never over a
/// level in progress, and never right after another full-screen ad (its
/// own dismissal resumes the app on Android).
final class AppOpenPolicy {
  const AppOpenPolicy({
    this.minCompletedLevels = 5,
    this.minTimeAway = const Duration(seconds: 30),
    this.cooldown = const Duration(minutes: 4),
    this.maxPerSession = 3,
  });

  final int minCompletedLevels;
  final Duration minTimeAway;

  /// Minimum gap since the last full-screen ad of any kind closed.
  final Duration cooldown;
  final int maxPerSession;

  bool shouldShow(
    PlayerProfile p, {
    required Duration timeAway,
    required Duration? sinceLastFullScreen,
    required bool inLevel,
    required int shownThisSession,
  }) =>
      interruptionsAllowed(p) &&
      !inLevel &&
      p.completions.length >= minCompletedLevels &&
      timeAway >= minTimeAway &&
      (sinceLastFullScreen == null || sinceLastFullScreen >= cooldown) &&
      shownThisSession < maxPerSession;
}
