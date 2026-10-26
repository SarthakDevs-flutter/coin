import 'package:flutter/widgets.dart';

import '../../application/ports/ports.dart';

/// Used when no ad SDK is available (tests, web, desktop). Reports every
/// request honestly as unavailable; never pretends an ad was watched.
final class UnconfiguredAds implements AdsPort {
  var _seq = 0;

  @override
  bool get isConfigured => false;

  @override
  Future<void> start() async {}

  @override
  void setInterruptionsEnabled(bool enabled) {}

  @override
  bool get isShowingFullScreen => false;

  @override
  DateTime? get lastFullScreenClosedAt => null;

  @override
  Future<bool> isRewardedReady() async => false;

  @override
  Future<({AdOutcome outcome, String token})> showRewarded(
    String placement,
  ) async => (
    outcome: AdOutcome.unavailable,
    token: 'none-${DateTime.now().microsecondsSinceEpoch}-${_seq++}',
  );

  @override
  Future<AdOutcome> showInterstitial(String placement) async =>
      AdOutcome.unavailable;

  @override
  Future<AdOutcome> showAppOpen(String placement) async =>
      AdOutcome.unavailable;

  @override
  Widget banner(String placement) => const SizedBox.shrink();

  @override
  Future<bool> privacyOptionsRequired() async => false;

  @override
  Future<void> showPrivacyOptions() async {}
}
