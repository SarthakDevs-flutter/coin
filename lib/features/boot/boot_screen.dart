import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../application/providers.dart';
import '../../data/save/save_repository.dart';
import '../common/widgets.dart';
import '../home/home_screen.dart';
import '../onboarding/welcome_screen.dart';

/// Flow A/B/K entry: loads levels and save, surfaces recovery honestly, then
/// routes to onboarding (first run) or home.
class BootScreen extends ConsumerWidget {
  const BootScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boot = ref.watch(bootProvider);
    return boot.when(
      data: (data) => _Ready(data: data),
      loading: () => const _Splash(),
      error: (e, _) =>
          _Splash(error: true, onRetry: () => ref.invalidate(bootProvider)),
    );
  }
}

class _Ready extends ConsumerStatefulWidget {
  const _Ready({required this.data});

  final BootData data;

  @override
  ConsumerState<_Ready> createState() => _ReadyState();
}

class _ReadyState extends ConsumerState<_Ready> {
  bool _notified = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_notified) return;
    _notified = true;
    final l = context.l10n;
    final msg = switch (widget.data.load.recovery) {
      LoadRecovery.fromBackup => l.recoveredFromBackup,
      LoadRecovery.reset => l.recoveredReset,
      _ => null,
    };
    if (msg != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showToast(context, msg);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(saveProvider.select((s) => s.profile));
    final firstRun = !profile.tutorialDone && profile.completions.isEmpty;
    return firstRun ? const WelcomeScreen() : const HomeScreen();
  }
}

class _Splash extends StatelessWidget {
  const _Splash({this.error = false, this.onRetry});

  final bool error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: AtelierBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AtelierSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMark(size: 110),
                  const SizedBox(height: 28),
                  Text(
                    l.appTitle,
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 18),
                  if (error) ...[
                    Text(
                      l.loadFailed,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: l.retry,
                      icon: Icons.refresh_rounded,
                      onPressed: onRetry,
                    ),
                  ] else
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        l.loading,
                        style: const TextStyle(
                          color: AtelierColors.textOnDarkMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
