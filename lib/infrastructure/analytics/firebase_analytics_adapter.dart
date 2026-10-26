import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../../application/ports/ports.dart';

/// Google Analytics for Firebase. Wrap in [ConsentGatedAnalytics].
///
/// Automatic collection is off in the platform manifests until consent, so
/// not even `first_open` leaves the device before the player agrees.
final class FirebaseAnalyticsAdapter implements AnalyticsPort {
  FirebaseAnalyticsAdapter([FirebaseAnalytics? analytics])
    : _fa = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _fa;

  @override
  void log(AnalyticsEvent event, [Map<String, Object> params = const {}]) {
    final (name, extra) = eventName(event, params);
    final parameters = {
      ...params,
      ...extra,
    }.map((k, v) => MapEntry(snakeCase(k), paramValue(v)));
    if (kDebugMode) debugPrint('[analytics] $name $parameters');
    unawaited(_guard(_fa.logEvent(name: name, parameters: parameters)));
  }

  @override
  void setCollectionEnabled(bool enabled) {
    unawaited(_guard(_fa.setAnalyticsCollectionEnabled(enabled)));
    // Consent Mode v2. Ad signals stay off: ads have their own consent (UMP).
    unawaited(
      _guard(
        _fa.setConsent(
          analyticsStorageConsentGranted: enabled,
          adStorageConsentGranted: false,
          adUserDataConsentGranted: false,
          adPersonalizationSignalsConsentGranted: false,
        ),
      ),
    );
  }

  @override
  void setUserId(String? id) => unawaited(_guard(_fa.setUserId(id: id)));

  @override
  void setUserProperty(String name, String? value) => unawaited(
    _guard(
      _fa.setUserProperty(
        name: name,
        value: value == null || value.length <= 36
            ? value
            : value.substring(0, 36),
      ),
    ),
  );

  /// GA4 recommended names where one exists (they unlock built-in reports),
  /// snake_case otherwise.
  static (String, Map<String, Object>) eventName(
    AnalyticsEvent event,
    Map<String, Object> params,
  ) {
    final level = params['level'];
    return switch (event) {
      AnalyticsEvent.levelStarted => ('level_start', {'level_name': ?level}),
      AnalyticsEvent.levelCompleted => (
        'level_end',
        {'level_name': ?level, 'success': 1},
      ),
      AnalyticsEvent.tutorialStarted => ('tutorial_begin', const {}),
      AnalyticsEvent.tutorialCompleted => ('tutorial_complete', const {}),
      _ => (snakeCase(event.name), const {}),
    };
  }

  static String snakeCase(String s) => s
      .replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}')
      .replaceAll(RegExp('[^a-z0-9_]'), '_');

  /// GA4 takes strings (max 100 chars) and numbers only.
  static Object paramValue(Object v) => switch (v) {
    bool b => b ? 1 : 0,
    num n => n,
    _ => v.toString().length > 100 ? v.toString().substring(0, 100) : '$v',
  };

  static Future<void> _guard(Future<void> f) =>
      f.catchError((Object e) => debugPrint('firebase analytics: $e'));
}
