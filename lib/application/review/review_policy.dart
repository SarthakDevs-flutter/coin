import '../../domain/model/level.dart';

/// When to ask the platform for a store rating (onboarding design §3.6).
/// Only after a clean first clear of a milestone level, and well inside the
/// platform quotas (iOS shows at most 3 per 365 days).
final class ReviewPolicy {
  const ReviewPolicy({
    this.milestones = const {12, 45, 120},
    this.minGap = const Duration(days: 120),
    this.maxPerYear = 3,
  });

  final Set<int> milestones;
  final Duration minGap;
  final int maxPerYear;

  /// [cleanAttempt]: no restart and no blocked board during this attempt.
  bool shouldRequest({
    required LevelDefinition level,
    required bool firstClear,
    required bool cleanAttempt,
    required List<DateTime> history,
    required DateTime now,
  }) {
    if (level.isTutorial || !firstClear || !cleanAttempt) return false;
    if (!milestones.contains(level.number)) return false;
    final yearAgo = now.subtract(const Duration(days: 365));
    if (history.where((t) => t.isAfter(yearAgo)).length >= maxPerYear) {
      return false;
    }
    return history.every((t) => now.difference(t) >= minGap);
  }
}
