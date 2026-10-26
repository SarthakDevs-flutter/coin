import 'dart:async';
import 'dart:math' as math;

/// Keeps one full-screen ad loaded ahead of need, SDK-agnostic.
///
/// - At most one load in flight.
/// - A cached ad older than [ttl] is thrown away and replaced (AdMob ads
///   expire: one hour for interstitial/rewarded, four for app-open).
/// - Failed loads retry with capped exponential backoff, so a no-fill or
///   offline device doesn't hammer the network.
/// - While disabled nothing loads and any cached ad is released.
final class PreloadedAd<T extends Object> {
  PreloadedAd({
    required this.name,
    required this._load,
    required this._release,
    required this.ttl,
    this.baseBackoff = const Duration(seconds: 4),
    this.maxBackoff = const Duration(minutes: 2),
    DateTime Function()? now,
    void Function(String message)? log,
  }) : _now = now ?? DateTime.now,
       _log = log ?? _noLog;

  final String name;
  final Duration ttl;
  final Duration baseBackoff;
  final Duration maxBackoff;
  final Future<T> Function() _load;
  final void Function(T ad) _release;
  final DateTime Function() _now;
  final void Function(String message) _log;

  T? _ad;
  DateTime? _loadedAt;
  Future<void>? _inFlight;
  Timer? _retry;
  int _failures = 0;
  bool _enabled = false;

  /// Bumped on disable, so a load that finishes afterwards is discarded.
  int _generation = 0;

  bool get isEnabled => _enabled;
  bool get isLoading => _inFlight != null;

  bool get isReady {
    final at = _loadedAt;
    return _ad != null && at != null && _now().difference(at) < ttl;
  }

  void enable() {
    _enabled = true;
    ensureLoaded();
  }

  void disable() {
    _enabled = false;
    _generation++;
    _retry?.cancel();
    _retry = null;
    _inFlight = null;
    _failures = 0;
    _drop();
  }

  /// Starts a load if nothing usable is cached and none is pending.
  void ensureLoaded() {
    if (!_enabled || _inFlight != null || _retry != null) return;
    if (isReady) return;
    _drop();
    _inFlight = _run(_generation);
  }

  /// Hands over the cached ad (the caller now owns and must release it).
  /// Returns null and starts a load when nothing fresh is cached. The next
  /// ad is not requested until the caller calls [ensureLoaded], usually
  /// once the current one is dismissed.
  T? take() {
    if (!isReady) {
      ensureLoaded();
      return null;
    }
    final ad = _ad;
    _ad = null;
    _loadedAt = null;
    return ad;
  }

  /// Completes true as soon as an ad is ready, false after [timeout] or if
  /// loading is backing off after a failure.
  Future<bool> waitUntilReady(Duration timeout) async {
    ensureLoaded();
    if (isReady) return true;
    final pending = _inFlight;
    if (pending == null) return false;
    await pending.timeout(timeout, onTimeout: () {});
    return isReady;
  }

  Future<void> _run(int generation) async {
    try {
      final ad = await _load();
      if (generation != _generation || !_enabled) {
        _release(ad);
        return;
      }
      _ad = ad;
      _loadedAt = _now();
      _failures = 0;
      _log('$name loaded');
    } on Object catch (e) {
      if (generation != _generation) return;
      _failures++;
      final delay = backoffFor(_failures);
      _log('$name failed ($e), retry in ${delay.inSeconds}s');
      _retry = Timer(delay, () {
        _retry = null;
        ensureLoaded();
      });
    } finally {
      if (generation == _generation) _inFlight = null;
    }
  }

  /// Delay before retry number [failures] (1-based): base, 2x, 4x... capped.
  Duration backoffFor(int failures) {
    final factor = math.pow(2, math.min(failures - 1, 16)).toInt();
    final ms = baseBackoff.inMilliseconds * factor;
    return Duration(milliseconds: math.min(ms, maxBackoff.inMilliseconds));
  }

  void _drop() {
    final ad = _ad;
    _ad = null;
    _loadedAt = null;
    if (ad != null) _release(ad);
  }

  static void _noLog(String _) {}
}
