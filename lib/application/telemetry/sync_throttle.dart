import 'dart:async';

/// Sends the newest value at most once per [minGap], dropping repeats.
///
/// Progress changes in bursts (a win updates gilt, completions and the
/// ledger at once); this turns every burst into one backend write, which
/// keeps Firestore costs flat as the player base grows.
final class SyncThrottle<T> {
  SyncThrottle(this._send, {this.minGap = const Duration(seconds: 30)});

  final void Function(T value) _send;
  final Duration minGap;

  T? _pending;
  bool _hasPending = false;
  T? _last;
  bool _hasLast = false;
  DateTime? _lastAt;
  Timer? _timer;

  void offer(T value) {
    if (_hasLast && _last == value) {
      _clearPending();
      return;
    }
    _pending = value;
    _hasPending = true;
    if (_timer != null) return;
    final at = _lastAt;
    final wait = at == null
        ? Duration.zero
        : minGap - DateTime.now().difference(at);
    if (wait <= Duration.zero) {
      flush();
    } else {
      _timer = Timer(wait, flush);
    }
  }

  /// Sends any pending value now (app going to background).
  void flush() {
    _timer?.cancel();
    _timer = null;
    if (!_hasPending) return;
    final value = _pending as T;
    _clearPending();
    _last = value;
    _hasLast = true;
    _lastAt = DateTime.now();
    _send(value);
  }

  /// Drops pending work and forgets what was sent (consent withdrawn).
  void reset() {
    _timer?.cancel();
    _timer = null;
    _clearPending();
    _last = null;
    _hasLast = false;
    _lastAt = null;
  }

  void _clearPending() {
    _pending = null;
    _hasPending = false;
  }
}
