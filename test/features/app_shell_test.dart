import 'package:coin/app/coin_atelier_app.dart';
import 'package:coin/application/providers.dart';
import 'package:coin/application/session/solver_runner.dart';
import 'package:coin/data/levels/level_repository.dart';
import 'package:coin/data/save/file_save_store.dart';
import 'package:coin/data/save/save_repository.dart';
import 'package:coin/features/shell/app_shell.dart';
import 'package:coin/infrastructure/ads/unconfigured_ads.dart';
import 'package:coin/infrastructure/analytics/analytics.dart';
import 'package:coin/infrastructure/audio/flame_audio_adapter.dart';
import 'package:coin/infrastructure/billing/unavailable_billing.dart';
import 'package:coin/infrastructure/crash_reporting/local_crash_reporter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../application/gameplay_flow_test.dart' show FileBundle, NoHaptics;

void main() {
  testWidgets('tabs switch, and Back on a tab returns Home', (t) async {
    t.view.physicalSize = const Size(393 * 3, 852 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final container = ProviderContainer(
      overrides: [
        servicesProvider.overrideWithValue(
          AppServices(
            saves: SaveRepository(MemorySaveStore()),
            levels: const LevelRepository(),
            bundle: FileBundle(),
            audio: const SilentAudio(),
            haptics: NoHaptics(),
            analytics: const ConsoleAnalytics(),
            crash: LocalCrashReporter(),
            ads: UnconfiguredAds(),
            billing: UnavailableBilling(),
            solver: const InlineSolverRunner(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await t.runAsync(() => container.read(bootProvider.future));
    // A returning player, so boot does not push the lesson.
    await t.runAsync(
      () => container
          .read(saveProvider.notifier)
          .updateProfile((p) => p.copyWith(tutorialDone: true)),
    );
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CoinAtelierApp(),
      ),
    );
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byType(AppShell), findsOneWidget);
    expect(container.read(shellTabProvider), ShellTab.home);

    await t.tap(find.bySemanticsLabel('Shop').last);
    await t.pump(const Duration(milliseconds: 300));
    expect(container.read(shellTabProvider), ShellTab.shop);

    // System Back goes Home instead of leaving the app.
    await t.binding.handlePopRoute();
    await t.pump(const Duration(milliseconds: 300));
    expect(container.read(shellTabProvider), ShellTab.home);
  });
}
