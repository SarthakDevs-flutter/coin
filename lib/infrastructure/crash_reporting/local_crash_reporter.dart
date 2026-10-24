import 'package:flutter/foundation.dart';

import '../../application/ports/ports.dart';

/// Keeps a bounded in-memory log of recent errors (shown on the support
/// screen as non-sensitive codes). Replace with a reviewed crash vendor.
final class LocalCrashReporter implements CrashReporter {
  static const int limit = 30;
  final List<String> recent = [];

  @override
  void record(
    Object error,
    StackTrace stack, {
    Map<String, Object> context = const {},
  }) {
    final line =
        '${DateTime.now().toUtc().toIso8601String()} ${error.runtimeType} $context';
    recent.add(line);
    if (recent.length > limit) recent.removeAt(0);
    if (kDebugMode) {
      debugPrint('[crash] $error $context\n$stack');
    }
  }
}
