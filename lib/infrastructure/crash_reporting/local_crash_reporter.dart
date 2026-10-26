import 'package:flutter/foundation.dart';

import '../../application/ports/ports.dart';

/// Keeps a bounded in-memory log of recent errors (shown on the support
/// screen as non-sensitive codes).
final class LocalCrashReporter implements CrashReporter, RecentErrorLog {
  static const int limit = 30;

  @override
  final List<String> recent = [];

  @override
  void record(
    Object error,
    StackTrace stack, {
    Map<String, Object> context = const {},
    bool fatal = false,
  }) {
    final line =
        '${DateTime.now().toUtc().toIso8601String()} ${error.runtimeType} $context';
    recent.add(line);
    if (recent.length > limit) recent.removeAt(0);
    if (kDebugMode) {
      debugPrint('[crash${fatal ? ':fatal' : ''}] $error $context\n$stack');
    }
  }

  @override
  void setUserId(String? id) {}
}
