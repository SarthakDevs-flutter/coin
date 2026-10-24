/// Interfaces to the outside world. Domain and application code depend only
/// on these; concrete adapters live in lib/infrastructure and lib/data.
library;

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

abstract interface class AdsPort {
  /// Whether any ad SDK is configured in this build.
  bool get isConfigured;

  Future<bool> isRewardedReady();

  /// Shows a rewarded ad. The returned token is unique per show and is the
  /// idempotency key for the reward.
  Future<({AdOutcome outcome, String token})> showRewarded(String placement);

  Future<AdOutcome> showInterstitial(String placement);
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
  tutorialCompleted,
  tutorialAbandoned,
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

abstract interface class AnalyticsPort {
  /// [params] may only contain level ids, counts, versions and enums.
  void log(AnalyticsEvent event, [Map<String, Object> params = const {}]);
}

abstract interface class CrashReporter {
  void record(
    Object error,
    StackTrace stack, {
    Map<String, Object> context = const {},
  });
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
