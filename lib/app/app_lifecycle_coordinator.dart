import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/ads/ad_policy.dart';
import '../application/ports/ports.dart';
import '../application/providers.dart';
import '../application/session/gameplay_controller.dart';

/// Flow H: on background, settle animations, persist and pause audio; on
/// resume, restore audio. Wall-clock time is never a penalty.
///
/// Also owns the ad lifecycle: consent and SDK start once the lesson is done,
/// Remove Ads switching interruptions off, and app-open ads on a warm return.
class AppLifecycleCoordinator extends ConsumerStatefulWidget {
  const AppLifecycleCoordinator({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLifecycleCoordinator> createState() =>
      _AppLifecycleCoordinatorState();
}

class _AppLifecycleCoordinatorState
    extends ConsumerState<AppLifecycleCoordinator> {
  late final AppLifecycleListener _listener;
  DateTime? _sessionStart;
  DateTime? _backgroundAt;
  ProviderSubscription<Object?>? _adsBinding;
  int _appOpensThisSession = 0;

  static const appOpenPolicy = AppOpenPolicy();

  @override
  void initState() {
    super.initState();
    _sessionStart = DateTime.now();
    _listener = AppLifecycleListener(
      onHide: _onBackground,
      onPause: _onBackground,
      onResume: _onResume,
      onDetach: _onBackground,
    );
    ref.read(servicesProvider).analytics.log(AnalyticsEvent.sessionStarted);
    ref.listenManual(bootProvider, (_, boot) {
      if (boot.hasValue) _bindAds();
    }, fireImmediately: true);
  }

  void _bindAds() {
    _adsBinding ??= ref.listenManual(
      saveProvider.select((s) => (s.profile.tutorialDone, s.profile.removeAds)),
      (_, _) {
        final profile = ref.read(saveProvider).profile;
        final ads = ref.read(servicesProvider).ads;
        // Consent is asked after the lesson, never over a first move.
        if (profile.tutorialDone) unawaited(ads.start());
        ads.setInterruptionsEnabled(interruptionsAllowed(profile));
      },
      fireImmediately: true,
    );
  }

  void _onBackground() {
    final s = ref.read(servicesProvider);
    s.audio.pauseAll();
    // A full-screen ad pauses the activity on Android; that is not the
    // player leaving.
    if (s.ads.isShowingFullScreen) return;
    _backgroundAt ??= DateTime.now();
    if (ref.read(bootProvider).hasValue) {
      ref.read(gameplayProvider.notifier).onBackground();
    }
    final start = _sessionStart;
    if (start != null) {
      s.analytics.log(AnalyticsEvent.sessionEnded, {
        'minutes': DateTime.now().difference(start).inMinutes,
      });
      _sessionStart = null;
    }
  }

  void _onResume() {
    final s = ref.read(servicesProvider);
    if (s.ads.isShowingFullScreen) return;
    s.audio.resumeAll();
    if (_sessionStart == null) {
      _sessionStart = DateTime.now();
      s.analytics.log(AnalyticsEvent.sessionStarted);
    }
    final away = _backgroundAt == null
        ? Duration.zero
        : DateTime.now().difference(_backgroundAt!);
    _backgroundAt = null;
    unawaited(_maybeAppOpen(away));
  }

  Future<void> _maybeAppOpen(Duration away) async {
    if (!ref.read(bootProvider).hasValue) return;
    final s = ref.read(servicesProvider);
    if (!s.ads.isConfigured) return;
    final closed = s.ads.lastFullScreenClosedAt;
    if (!appOpenPolicy.shouldShow(
      ref.read(saveProvider).profile,
      timeAway: away,
      sinceLastFullScreen: closed == null
          ? null
          : DateTime.now().difference(closed),
      inLevel: ref.read(gameplayProvider.notifier).isInLevel,
      shownThisSession: _appOpensThisSession,
    )) {
      return;
    }
    s.analytics.log(AnalyticsEvent.adRequested, {'placement': 'app_open'});
    final outcome = await s.ads.showAppOpen('app_open');
    if (outcome == AdOutcome.completed) {
      _appOpensThisSession++;
      s.analytics.log(AnalyticsEvent.adShown, {'placement': 'app_open'});
    } else {
      s.analytics.log(AnalyticsEvent.adFailed, {
        'placement': 'app_open',
        'outcome': outcome.name,
      });
    }
  }

  @override
  void dispose() {
    _adsBinding?.close();
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
