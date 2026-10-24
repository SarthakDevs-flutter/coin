import '../../domain/progression/player_profile.dart';

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
      !p.removeAds &&
      p.tutorialDone &&
      p.completions.length >= minCompletedLevels &&
      p.levelsCompletedSinceInterstitial >= levelsBetween &&
      shownThisSession < maxPerSession;
}
