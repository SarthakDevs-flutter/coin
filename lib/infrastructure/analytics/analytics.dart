import 'package:flutter/foundation.dart';

import '../../application/ports/ports.dart';

/// Drops every event unless the player has opted in.
final class ConsentGatedAnalytics implements AnalyticsPort {
  ConsentGatedAnalytics(this._delegate, this._hasConsent);

  final AnalyticsPort _delegate;
  final bool Function() _hasConsent;

  @override
  void log(AnalyticsEvent event, [Map<String, Object> params = const {}]) {
    if (_hasConsent()) _delegate.log(event, params);
  }
}

/// No vendor is configured: events go to the debug console in debug builds
/// and nowhere in release builds. Swap for a reviewed vendor adapter.
final class ConsoleAnalytics implements AnalyticsPort {
  const ConsoleAnalytics();

  @override
  void log(AnalyticsEvent event, [Map<String, Object> params = const {}]) {
    if (kDebugMode) debugPrint('[analytics] ${event.name} $params');
  }
}
