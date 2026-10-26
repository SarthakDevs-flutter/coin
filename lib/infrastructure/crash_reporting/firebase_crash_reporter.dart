import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../../application/ports/ports.dart';
import 'local_crash_reporter.dart';

/// Crashlytics plus the local log the support screen shows. Reports carry
/// stack traces, app state codes and a pseudonymous id; never personal data.
final class FirebaseCrashReporter implements CrashReporter, RecentErrorLog {
  FirebaseCrashReporter({FirebaseCrashlytics? crashlytics})
    : _c = crashlytics ?? FirebaseCrashlytics.instance {
    // Debug crashes are noise in the dashboard.
    unawaited(_c.setCrashlyticsCollectionEnabled(!kDebugMode));
  }

  final FirebaseCrashlytics _c;
  final _local = LocalCrashReporter();

  @override
  List<String> get recent => _local.recent;

  @override
  void record(
    Object error,
    StackTrace stack, {
    Map<String, Object> context = const {},
    bool fatal = false,
  }) {
    _local.record(error, stack, context: context, fatal: fatal);
    unawaited(
      _c
          .recordError(
            error,
            stack,
            fatal: fatal,
            reason: context['where'] ?? context['source'],
            information: [
              for (final MapEntry(:key, :value) in context.entries)
                '$key=$value',
            ],
          )
          .catchError((Object _) {}),
    );
  }

  @override
  void setUserId(String? id) =>
      unawaited(_c.setUserIdentifier(id ?? '').catchError((Object _) {}));

  /// Breadcrumb shown with the next report.
  void breadcrumb(String message) => unawaited(_c.log(message));

  void setKey(String key, Object value) =>
      unawaited(_c.setCustomKey(key, value));
}
