import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/coin_atelier_app.dart';
import 'application/providers.dart';
import 'application/session/solver_runner.dart';
import 'data/levels/level_repository.dart';
import 'data/save/file_save_store.dart';
import 'data/save/save_repository.dart';
import 'infrastructure/ads/unconfigured_ads.dart';
import 'infrastructure/analytics/analytics.dart';
import 'infrastructure/audio/flame_audio_adapter.dart';
import 'infrastructure/billing/unavailable_billing.dart';
import 'infrastructure/crash_reporting/local_crash_reporter.dart';
import 'infrastructure/haptics/system_haptics.dart';

/// Composition root: picks concrete adapters for every port.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final crash = LocalCrashReporter();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    crash.record(
      details.exception,
      details.stack ?? StackTrace.empty,
      context: {'source': 'flutter'},
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    crash.record(error, stack, context: {'source': 'platform'});
    return true;
  };
  unawaited(
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]),
  );

  final audio = FlameAudioAdapter();
  final services = AppServices(
    saves: SaveRepository(FileSaveStore()),
    levels: const LevelRepository(),
    bundle: rootBundle,
    audio: audio,
    haptics: SystemHaptics(() => SettingsMirror.current.haptics),
    analytics: ConsentGatedAnalytics(
      const ConsoleAnalytics(),
      () => SettingsMirror.current.analyticsConsent,
    ),
    crash: crash,
    ads: UnconfiguredAds(),
    billing: UnavailableBilling(),
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
