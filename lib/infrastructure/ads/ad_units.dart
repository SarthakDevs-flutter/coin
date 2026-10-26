import 'package:flutter/foundation.dart';

/// AdMob ad unit ids for one platform. Mediation is configured per unit in
/// the AdMob console (mediation groups), so these ids never change when a
/// network is added.
final class AdUnits {
  const AdUnits({
    required this.appOpen,
    required this.banner,
    required this.interstitial,
    required this.rewarded,
  });

  final String appOpen;
  final String banner;
  final String interstitial;
  final String rewarded;

  bool get isComplete =>
      [appOpen, banner, interstitial, rewarded].every((id) => id.isNotEmpty);

  // Google's public sample units: always fill, never pay, safe to click.
  static const androidTest = AdUnits(
    appOpen: 'ca-app-pub-3940256099942544/9257395921',
    banner: 'ca-app-pub-3940256099942544/9214589741',
    interstitial: 'ca-app-pub-3940256099942544/1033173712',
    rewarded: 'ca-app-pub-3940256099942544/5224354917',
  );

  static const iosTest = AdUnits(
    appOpen: 'ca-app-pub-3940256099942544/5575463023',
    banner: 'ca-app-pub-3940256099942544/2435281174',
    interstitial: 'ca-app-pub-3940256099942544/4411468910',
    rewarded: 'ca-app-pub-3940256099942544/1712485313',
  );

  // TODO(ads): paste production unit ids from the AdMob console, and the
  // matching app ids in AndroidManifest.xml and ios/Runner/Info.plist.
  static const androidProduction = AdUnits(
    appOpen: '',
    banner: '',
    interstitial: '',
    rewarded: '',
  );

  static const iosProduction = AdUnits(
    appOpen: '',
    banner: '',
    interstitial: '',
    rewarded: '',
  );

  /// Debug and profile builds always use test units: requesting live ads
  /// from a development device risks the AdMob account. Release builds use
  /// production units once they are filled in.
  static AdUnits? forPlatform(TargetPlatform platform) {
    final (test, production) = switch (platform) {
      TargetPlatform.android => (androidTest, androidProduction),
      TargetPlatform.iOS => (iosTest, iosProduction),
      _ => (null, null),
    };
    if (test == null || production == null) return null;
    if (kReleaseMode && production.isComplete) return production;
    if (kReleaseMode) {
      debugPrint('ads: production unit ids missing, serving test ads');
    }
    return test;
  }
}
