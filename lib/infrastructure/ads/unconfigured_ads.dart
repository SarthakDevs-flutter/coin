import '../../application/ports/ports.dart';

/// Used until a real ad SDK and account are wired in. Reports every request
/// honestly as unavailable; never pretends an ad was watched.
final class UnconfiguredAds implements AdsPort {
  var _seq = 0;

  @override
  bool get isConfigured => false;

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
}
