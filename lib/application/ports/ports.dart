/// Interfaces to the outside world. Domain and application code depend only
/// on these; concrete adapters live in lib/infrastructure and lib/data.
library;

import 'package:flutter/widgets.dart';

/// Raw byte-free key/value storage for save files. Implementations must make
/// [write] atomic (write-temp-then-rename or equivalent).
abstract interface class SaveStore {
  Future<String?> read(String name);
  Future<void> write(String name, String contents);
  Future<void> delete(String name);
}

abstract interface class Clock {
  DateTime now();
}

final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

// ---- ads -------------------------------------------------------------------

enum AdOutcome {
  /// SDK confirmed the user watched to completion.
  completed,

  /// Closed early: no reward.
  dismissed,

  /// No fill, no network, no consent, or no SDK configured.
  unavailable,

  failed,
}

/// Provider-agnostic ad service. Today one AdMob adapter backs it; further
/// demand sources plug in through AdMob mediation, so callers never change.
abstract interface class AdsPort {
  /// Whether any ad SDK is configured in this build.
  bool get isConfigured;

  /// Gathers privacy consent where the law requires it, starts the SDK and
  /// begins preloading. Idempotent; safe to call on every launch.
  Future<void> start();

  /// Turns banners, interstitials and app-open ads on or off (Remove Ads,
  /// first-time players). Rewarded ads are opt-in and stay available.
  void setInterruptionsEnabled(bool enabled);

  /// True while a full-screen ad covers the app.
  bool get isShowingFullScreen;

  /// When the last full-screen ad closed, for spacing rules.
  DateTime? get lastFullScreenClosedAt;

  /// Waits briefly for a preloaded rewarded ad, so a tap right after launch
  /// still gets one.
  Future<bool> isRewardedReady();

  /// Shows a rewarded ad. The returned token is unique per show and is the
  /// idempotency key for the reward.
  Future<({AdOutcome outcome, String token})> showRewarded(String placement);

  /// Shows a preloaded interstitial, or returns [AdOutcome.unavailable]
  /// immediately. Never waits on the network.
  Future<AdOutcome> showInterstitial(String placement);

  /// Shows a preloaded app-open ad, or returns [AdOutcome.unavailable].
  Future<AdOutcome> showAppOpen(String placement);

  /// An anchored banner sized to its parent's width. Takes no space until an
  /// ad has loaded, and none at all while interruptions are off.
  Widget banner(String placement);

  /// Whether the consent framework requires a "privacy choices" entry point.
  Future<bool> privacyOptionsRequired();

  /// Reopens the consent form so the player can change their choice.
  Future<void> showPrivacyOptions();
}

// ---- billing ---------------------------------------------------------------

enum PurchaseStatus { pending, purchased, canceled, failed, restored, refunded }

final class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.priceLabel,
  });

  final String id;
  final String title;
  final String description;

  /// Localized price string from the store. Never hardcoded.
  final String priceLabel;
}

final class PurchaseUpdate {
  const PurchaseUpdate({
    required this.productId,
    required this.status,
    required this.transactionId,
  });

  final String productId;
  final PurchaseStatus status;
  final String transactionId;
}

abstract interface class BillingPort {
  bool get isAvailable;
  Future<List<StoreProduct>> products(Set<String> ids);
  Future<void> buy(String productId);
  Future<void> restore();
  Stream<PurchaseUpdate> get updates;
}

// ---- analytics / diagnostics ----------------------------------------------

/// Allow-listed product events (design.md §13). No free-form payloads.
enum AnalyticsEvent {
  sessionStarted,
  sessionEnded,
  tutorialStarted,
  tutorialStep,
  tutorialCompleted,
  tutorialAbandoned,
  idleNudgeShown,
  coachTipShown,
  privacyPromptResult,
  reviewRequested,
  levelStarted,
  levelCompleted,
  levelRestarted,
  undoUsed,
  hintUsed,
  boosterUsed,
  verifiedNoMovesState,
  adRequested,
  adShown,
  adCompleted,
  adFailed,
  purchaseStarted,
  purchaseCompleted,
  purchaseFailed,
  purchaseRestored,
  saveRestoreSuccess,
  saveRestoreFailure,
}

// ---- store rating -----------------------------------------------------------

abstract interface class ReviewPort {
  /// Asks the platform for its rating sheet. The OS decides whether it shows
  /// (quotas apply), so callers must never depend on it appearing.
  Future<void> request();
}

/// No platform review API in this build.
final class NoReview implements ReviewPort {
  const NoReview();

  @override
  Future<void> request() async {}
}

abstract interface class AnalyticsPort {
  /// [params] may only contain level ids, counts, versions and enums.
  void log(AnalyticsEvent event, [Map<String, Object> params = const {}]);

  /// Turns all collection (including the vendor's automatic events) on or
  /// off. Follows the player's analytics consent.
  void setCollectionEnabled(bool enabled);

  /// Pseudonymous id (never a hardware id or anything personal), or null to
  /// clear it.
  void setUserId(String? id);

  /// Segment dimension such as country or highest level. Null clears it.
  void setUserProperty(String name, String? value);
}

abstract interface class CrashReporter {
  /// [fatal] marks errors that took down the Flutter frame or isolate.
  void record(
    Object error,
    StackTrace stack, {
    Map<String, Object> context = const {},
    bool fatal = false,
  });

  /// Attaches a pseudonymous id to later reports, or clears it.
  void setUserId(String? id);
}

/// Reporters that keep recent error codes for the support screen.
abstract interface class RecentErrorLog {
  List<String> get recent;
}

// ---- remote player mirror --------------------------------------------------

/// Non-sensitive player facts mirrored to the backend for support and
/// live-ops. Only sent with analytics consent.
final class PlayerSnapshot {
  const PlayerSnapshot({
    required this.platform,
    required this.appVersion,
    required this.build,
    required this.country,
    required this.locale,
    required this.highestLevel,
    required this.levelsCompleted,
    required this.tutorialDone,
    required this.removeAds,
  });

  final String platform;
  final String appVersion;
  final int build;

  /// Device region setting (ISO 3166 alpha-2), not a location fix.
  final String? country;
  final String locale;
  final int highestLevel;
  final int levelsCompleted;
  final bool tutorialDone;
  final bool removeAds;

  List<Object?> get _fields => [
    platform,
    appVersion,
    build,
    country,
    locale,
    highestLevel,
    levelsCompleted,
    tutorialDone,
    removeAds,
  ];

  @override
  bool operator ==(Object other) {
    if (other is! PlayerSnapshot) return false;
    final a = _fields, b = other._fields;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_fields);
}

abstract interface class PlayerSyncPort {
  /// Pseudonymous id of this install on the backend, once signed in.
  Future<String?> playerId();

  /// Upserts the player's record. Offline writes queue and retry.
  Future<void> push(PlayerSnapshot snapshot);

  /// Deletes the player's record (consent withdrawn, progress reset).
  Future<void> erase();
}

final class NoPlayerSync implements PlayerSyncPort {
  const NoPlayerSync();

  @override
  Future<String?> playerId() async => null;

  @override
  Future<void> push(PlayerSnapshot snapshot) async {}

  @override
  Future<void> erase() async {}
}

// ---- app updates -------------------------------------------------------------

enum UpdateUrgency { none, optional, required }

final class UpdateInfo {
  const UpdateInfo({required this.urgency, this.latestBuild = 0, this.message});

  static const none = UpdateInfo(urgency: UpdateUrgency.none);

  final UpdateUrgency urgency;
  final int latestBuild;

  /// Optional release note from the backend, shown as-is.
  final String? message;
}

abstract interface class AppUpdatePort {
  /// Compares this build with the published minimum and latest builds.
  /// Never throws; any failure reads as [UpdateInfo.none].
  Future<UpdateInfo> check();

  /// Starts the platform update flow (Play in-app update, else the store).
  Future<void> startUpdate(UpdateInfo info);
}

final class NoAppUpdate implements AppUpdatePort {
  const NoAppUpdate();

  @override
  Future<UpdateInfo> check() async => UpdateInfo.none;

  @override
  Future<void> startUpdate(UpdateInfo info) async {}
}

// ---- feedback --------------------------------------------------------------

enum Sfx {
  select,
  deselect,
  land,
  fuse,
  seal,
  thaw,
  reveal,
  invalid,
  undo,
  win,
  tap,
  reward,
  whoosh,
  deal,
  chain,
}

abstract interface class AudioPort {
  Future<void> preload();
  void play(Sfx sfx);

  /// A coin landing, [order] = its place in the current run (0 = first).
  /// Successive landings climb a gentle scale.
  void playLanding(int order);
  void setMusicEnabled(bool enabled);
  void setSfxEnabled(bool enabled);
  void pauseAll();
  void resumeAll();
}

enum HapticKind { light, medium, success, warning }

abstract interface class HapticsPort {
  void play(HapticKind kind);
}
