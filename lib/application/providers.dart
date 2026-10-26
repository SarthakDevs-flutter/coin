import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ports/ports.dart';
import 'session/solver_runner.dart';
import 'state/save_data.dart';
import 'state/settings.dart';
import '../data/levels/level_repository.dart';
import '../data/save/save_repository.dart';
import '../domain/model/level_pack.dart';
import '../domain/progression/player_profile.dart';

/// Concrete adapters chosen at startup (main.dart) or in tests.
final class AppServices {
  AppServices({
    required this.saves,
    required this.levels,
    required this.bundle,
    required this.audio,
    required this.haptics,
    required this.analytics,
    required this.crash,
    required this.ads,
    required this.billing,
    required this.solver,
    this.review = const NoReview(),
    this.playerSync = const NoPlayerSync(),
    this.appUpdate = const NoAppUpdate(),
    this.clock = const SystemClock(),
    this.appVersion = '1.0.0',
    this.appBuild = 1,
  });

  final SaveRepository saves;
  final LevelRepository levels;
  final AssetBundle bundle;
  final AudioPort audio;
  final HapticsPort haptics;
  final AnalyticsPort analytics;
  final CrashReporter crash;
  final AdsPort ads;
  final BillingPort billing;
  final SolverRunner solver;
  final ReviewPort review;
  final PlayerSyncPort playerSync;
  final AppUpdatePort appUpdate;
  final Clock clock;
  final String appVersion;
  final int appBuild;
}

/// Latest settings, readable from adapters that are created before Riverpod
/// (haptics, analytics consent gate).
final class SettingsMirror {
  static GameSettings current = const GameSettings();
}

final servicesProvider = Provider<AppServices>(
  (ref) => throw UnimplementedError('servicesProvider must be overridden'),
);

final class BootData {
  const BootData({
    required this.pack,
    required this.load,
    required this.rejectedLevels,
  });

  final LevelPack pack;
  final LoadResult load;
  final List<String> rejectedLevels;
}

/// Loads levels and the save in parallel. Failures surface on the boot screen
/// with a retry; nothing is silently reset.
final bootProvider = FutureProvider<BootData>((ref) async {
  final s = ref.watch(servicesProvider);
  final results = await Future.wait([s.levels.load(s.bundle), s.saves.load()]);
  final loaded = results[0] as LoadedPack;
  final load = results[1] as LoadResult;
  for (final id in loaded.rejectedIds) {
    s.crash.record(
      StateError('level_rejected'),
      StackTrace.current,
      context: {'level': id},
    );
  }
  s.analytics.log(
    load.recovery == LoadRecovery.reset
        ? AnalyticsEvent.saveRestoreFailure
        : AnalyticsEvent.saveRestoreSuccess,
    {'recovery': load.recovery.name, 'code': load.errorCode ?? 'none'},
  );
  SettingsMirror.current = load.data.settings;
  s.audio
    ..setSfxEnabled(load.data.settings.sfx)
    ..setMusicEnabled(load.data.settings.music);
  return BootData(
    pack: loaded.pack,
    load: load,
    rejectedLevels: loaded.rejectedIds,
  );
});

final packProvider = Provider<LevelPack>(
  (ref) => ref.watch(bootProvider).requireValue.pack,
);

/// Single source of persisted truth. Every mutation persists.
final saveProvider = NotifierProvider<SaveController, SaveData>(
  SaveController.new,
);

final class SaveController extends Notifier<SaveData> {
  @override
  SaveData build() => ref.watch(bootProvider).requireValue.load.data;

  AppServices get _s => ref.read(servicesProvider);

  Future<void> _commit(SaveData next) {
    state = next;
    return _s.saves.save(next);
  }

  Future<void> updateProfile(PlayerProfile Function(PlayerProfile p) f) =>
      _commit(state.copyWith(profile: f(state.profile)));

  Future<void> updateSettings(GameSettings Function(GameSettings s) f) {
    final next = f(state.settings);
    SettingsMirror.current = next;
    _s.audio
      ..setSfxEnabled(next.sfx)
      ..setMusicEnabled(next.music);
    return _commit(state.copyWith(settings: next));
  }

  Future<void> setActiveSession(Map<String, Object?>? session) =>
      _commit(state.copyWith(activeSession: () => session));

  /// Profile change and session clear land in the same write, so completion
  /// and its reward are persisted atomically.
  Future<void> commit({
    PlayerProfile? profile,
    Map<String, Object?>? Function()? activeSession,
  }) => _commit(state.copyWith(profile: profile, activeSession: activeSession));

  Future<void> flush() => _s.saves.flush();

  Future<void> resetProgress() async {
    await _s.saves.wipe();
    // The backend mirror goes with the local progress.
    await _s.playerSync.erase();
    await _commit(
      SaveData(profile: PlayerProfile.fresh(), settings: state.settings),
    );
  }
}

/// Exposes save-health so the UI can show a non-blocking warning.
final saveHealthProvider = StreamProvider<SaveHealth>((ref) {
  final saves = ref.watch(servicesProvider).saves;
  final controller = StreamController<SaveHealth>();
  controller.add(saves.health);
  final sub = saves.healthChanges.listen(controller.add);
  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });
  return controller.stream;
});
