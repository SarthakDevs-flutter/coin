import 'package:flutter/foundation.dart';

import '../../application/ports/ports.dart';

/// Drops every event unless the player has opted in, and keeps the vendor's
/// own collection switch in step with that consent.
final class ConsentGatedAnalytics implements AnalyticsPort {
  ConsentGatedAnalytics(this._delegate, this._hasConsent);

  final AnalyticsPort _delegate;
  final bool Function() _hasConsent;

  @override
  void log(AnalyticsEvent event, [Map<String, Object> params = const {}]) {
    if (_hasConsent()) _delegate.log(event, params);
  }

  @override
  void setCollectionEnabled(bool enabled) =>
      _delegate.setCollectionEnabled(enabled && _hasConsent());

  @override
  void setUserId(String? id) {
    if (id == null || _hasConsent()) _delegate.setUserId(id);
  }

  @override
  void setUserProperty(String name, String? value) {
    if (value == null || _hasConsent()) _delegate.setUserProperty(name, value);
  }
}

/// No vendor is configured: events go to the debug console in debug builds
/// and nowhere in release builds.
final class ConsoleAnalytics implements AnalyticsPort {
  const ConsoleAnalytics();

  @override
  void log(AnalyticsEvent event, [Map<String, Object> params = const {}]) {
    if (kDebugMode) debugPrint('[analytics] ${event.name} $params');
  }

  @override
  void setCollectionEnabled(bool enabled) {}

  @override
  void setUserId(String? id) {}

  @override
  void setUserProperty(String name, String? value) {
    if (kDebugMode) debugPrint('[analytics] user.$name = $value');
  }
}
