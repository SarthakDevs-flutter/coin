import 'dart:ui' show Locale;

import '../../domain/model/level_pack.dart';
import '../../domain/progression/player_profile.dart';
import '../ports/ports.dart';

/// Builds the backend mirror of [p]. Country and locale come from the
/// device's region and language settings; no location permission is used.
PlayerSnapshot snapshotOf(
  PlayerProfile p,
  LevelPack pack, {
  required String platform,
  required String appVersion,
  required int build,
  required Locale deviceLocale,
}) {
  var highest = 0;
  for (final id in p.completions.keys) {
    final n = pack.byId(id)?.number ?? 0;
    if (n > highest) highest = n;
  }
  return PlayerSnapshot(
    platform: platform,
    appVersion: appVersion,
    build: build,
    country: deviceLocale.countryCode?.toUpperCase(),
    locale: deviceLocale.toLanguageTag(),
    highestLevel: highest,
    levelsCompleted: p.completions.length,
    tutorialDone: p.tutorialDone,
    removeAds: p.removeAds,
  );
}

/// Analytics user properties for [s] (GA4 allows 25, 36-char values).
Map<String, String?> userPropertiesOf(PlayerSnapshot s) => {
  'country': s.country,
  'app_locale': s.locale,
  'highest_level': '${s.highestLevel}',
  'levels_done': _bucket(s.levelsCompleted),
  'tutorial_done': '${s.tutorialDone}',
  'remove_ads': '${s.removeAds}',
};

/// Coarse buckets keep audiences stable and the property cardinality low.
String _bucket(int n) => switch (n) {
  0 => '0',
  < 5 => '1-4',
  < 10 => '5-9',
  < 25 => '10-24',
  < 50 => '25-49',
  < 100 => '50-99',
  _ => '100+',
};
