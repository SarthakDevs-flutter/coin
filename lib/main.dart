import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app/coin_atelier_app.dart';
import 'application/ports/ports.dart';
import 'application/providers.dart';
import 'application/session/solver_runner.dart';
import 'data/levels/level_repository.dart';
import 'data/save/file_save_store.dart';
import 'data/save/save_repository.dart';
import 'infrastructure/ads/ad_units.dart';
import 'infrastructure/ads/admob_ads.dart';
import 'infrastructure/ads/unconfigured_ads.dart';
import 'infrastructure/analytics/analytics.dart';
import 'infrastructure/analytics/firebase_analytics_adapter.dart';
import 'infrastructure/audio/flame_audio_adapter.dart';
import 'infrastructure/billing/unavailable_billing.dart';
import 'infrastructure/crash_reporting/firebase_crash_reporter.dart';
import 'infrastructure/crash_reporting/local_crash_reporter.dart';
import 'infrastructure/firebase/firebase_bootstrap.dart';
import 'infrastructure/player_sync/firestore_player_sync.dart';
import 'infrastructure/update/firestore_app_update.dart';
import 'infrastructure/haptics/system_haptics.dart';
import 'infrastructure/review/platform_review.dart';

/// Composition root: picks concrete adapters for every port. Firebase-backed
/// adapters are used when the project is configured (`flutterfire
/// configure`); otherwise the local ones keep the game fully working.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final (firebase, package) = await (
    FirebaseBootstrap.start(),
    PackageInfo.fromPlatform(),
  ).wait;
  final CrashReporter crash = firebase
      ? FirebaseCrashReporter()
      : LocalCrashReporter();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    crash.record(
      details.exception,
      details.stack ?? StackTrace.empty,
      context: {'source': 'flutter'},
      fatal: !details.silent,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    crash.record(error, stack, context: {'source': 'platform'}, fatal: true);
    return true;
  };
  unawaited(
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
  );

  final audio = FlameAudioAdapter();
  final build = int.tryParse(package.buildNumber) ?? 0;
  final adUnits = kIsWeb ? null : AdUnits.forPlatform(defaultTargetPlatform);
  final AdsPort ads = adUnits == null
      ? UnconfiguredAds()
      : AdmobAds(
          adUnits,
          onFullScreenChanged: (showing) =>
              showing ? audio.pauseAll() : audio.resumeAll(),
        );
  final services = AppServices(
    saves: SaveRepository(FileSaveStore()),
    levels: const LevelRepository(),
    bundle: rootBundle,
    audio: audio,
    haptics: SystemHaptics(() => SettingsMirror.current.haptics),
    analytics: ConsentGatedAnalytics(
      firebase ? FirebaseAnalyticsAdapter() : const ConsoleAnalytics(),
      () => SettingsMirror.current.analyticsConsent,
    ),
    crash: crash,
    ads: ads,
    billing: UnavailableBilling(),
    review: const PlatformReview(),
    playerSync: firebase ? FirestorePlayerSync() : const NoPlayerSync(),
    appUpdate: firebase
        ? FirestoreAppUpdate(
            build: build,
            platform: defaultTargetPlatform == TargetPlatform.iOS
                ? 'ios'
                : 'android',
          )
        : const NoAppUpdate(),
    appVersion: package.version,
    appBuild: build,
    solver: SerialSolverRunner(
      kIsWeb ? const InlineSolverRunner() : const IsolateSolverRunner(),
    ),
  );
  unawaited(audio.preload());

  runApp(
    ProviderScope(
      overrides: [servicesProvider.overrideWithValue(services)],
      child: const CoinAtelierApp(),
    ),
  );
}
