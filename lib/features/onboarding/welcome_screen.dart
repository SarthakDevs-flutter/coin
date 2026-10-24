import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../application/providers.dart';
import '../common/widgets.dart';
import '../gameplay/gameplay_screen.dart';

/// First-run welcome: one-sentence promise, then straight into the hands-on
/// lesson. No ads, no permission prompts.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    final tutorial = ref.watch(packProvider).levels.first;
    return Scaffold(
      body: AtelierBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AtelierSpacing.lg,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    const BrandMark(size: 130),
                    const SizedBox(height: 32),
                    Text(
                      l.welcomeTitle,
                      textAlign: TextAlign.center,
                      style: theme.displayMedium,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      l.tagline,
                      textAlign: TextAlign.center,
                      style: theme.titleMedium?.copyWith(
                        color: AtelierColors.accent,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l.welcomeBody,
                      textAlign: TextAlign.center,
                      style: theme.bodyLarge?.copyWith(
                        color: AtelierColors.textOnDarkMuted,
                      ),
                    ),
                    const SizedBox(height: 40),
                    PrimaryButton(
                      label: l.startTutorial,
                      icon: Icons.play_arrow_rounded,
                      large: true,
                      onPressed: () => Navigator.of(context).push(
                        atelierRoute(GameplayScreen(levelId: tutorial.id)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
