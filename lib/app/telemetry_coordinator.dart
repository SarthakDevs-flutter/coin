import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/ports/ports.dart';
import '../application/providers.dart';
import '../application/telemetry/player_snapshot.dart';
import '../application/telemetry/sync_throttle.dart';

/// Keeps analytics, crash reports and the backend player record in step with
/// the player's analytics consent and progress.
///
/// Consent on: collection enabled, pseudonymous id attached, user properties
/// and the `players/{id}` record kept current (throttled). Consent off:
/// collection stops, the id is detached and the backend record is deleted.
class TelemetryCoordinator extends ConsumerStatefulWidget {
  const TelemetryCoordinator({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TelemetryCoordinator> createState() =>
      _TelemetryCoordinatorState();
}

class _TelemetryCoordinatorState extends ConsumerState<TelemetryCoordinator> {
  late final AppLifecycleListener _lifecycle;
  late final SyncThrottle<PlayerSnapshot> _throttle;
  ProviderSubscription<bool>? _consentSub;
  ProviderSubscription<Object?>? _profileSub;
  bool? _consent;
  PlayerSnapshot? _propsFor;

  AppServices get _s => ref.read(servicesProvider);

  @override
  void initState() {
    super.initState();
    _throttle = SyncThrottle((s) => unawaited(_s.playerSync.push(s)));
    _lifecycle = AppLifecycleListener(onPause: _throttle.flush);
    ref.listenManual(bootProvider, (_, boot) {
      if (boot.hasValue) _bind();
    }, fireImmediately: true);
  }

  void _bind() {
    _consentSub ??= ref.listenManual(
      saveProvider.select((s) => s.settings.analyticsConsent),
      (_, consent) => unawaited(_onConsent(consent)),
      fireImmediately: true,
    );
    _profileSub ??= ref.listenManual(
      saveProvider.select((s) => s.profile),
      (_, _) => _onProgress(),
    );
  }

  Future<void> _onConsent(bool consent) async {
    final was = _consent;
    _consent = consent;
    final s = _s;
    s.analytics.setCollectionEnabled(consent);
    if (consent) {
      final id = await s.playerSync.playerId();
      if (!mounted || _consent != true) return;
      s.analytics.setUserId(id);
      s.crash.setUserId(id);
      _propsFor = null;
      _onProgress();
    } else if (was == true) {
      _throttle.reset();
      _propsFor = null;
      s.analytics.setUserId(null);
      s.crash.setUserId(null);
      await s.playerSync.erase();
    }
  }

  void _onProgress() {
    if (_consent != true) return;
    final s = _s;
    final snapshot = snapshotOf(
      ref.read(saveProvider).profile,
      ref.read(packProvider),
      platform: defaultTargetPlatform.name,
      appVersion: s.appVersion,
      build: s.appBuild,
      deviceLocale: WidgetsBinding.instance.platformDispatcher.locale,
    );
    if (snapshot == _propsFor) return;
    _propsFor = snapshot;
    for (final MapEntry(:key, :value) in userPropertiesOf(snapshot).entries) {
      s.analytics.setUserProperty(key, value);
    }
    _throttle.offer(snapshot);
  }

  @override
  void dispose() {
    _throttle.flush();
    _consentSub?.close();
    _profileSub?.close();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
