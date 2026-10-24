import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/ports/ports.dart';
import '../application/providers.dart';
import '../application/session/gameplay_controller.dart';

/// Flow H: on background, settle animations, persist and pause audio; on
/// resume, restore audio. Wall-clock time is never a penalty.
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
  }

  void _onBackground() {
    final s = ref.read(servicesProvider);
    s.audio.pauseAll();
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
    s.audio.resumeAll();
    if (_sessionStart == null) {
      _sessionStart = DateTime.now();
      s.analytics.log(AnalyticsEvent.sessionStarted);
    }
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
