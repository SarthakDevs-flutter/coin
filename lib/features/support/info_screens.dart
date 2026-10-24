import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../application/providers.dart';
import '../../infrastructure/crash_reporting/local_crash_reporter.dart';
import '../common/widgets.dart';

enum _InfoKind { privacy, support, credits }

/// Privacy, support and credits pages. Text is localised; nothing here makes
/// network calls.
class InfoScreen extends ConsumerWidget {
  const InfoScreen._(this._kind);

  factory InfoScreen.privacy() => const InfoScreen._(_InfoKind.privacy);
  factory InfoScreen.support() => const InfoScreen._(_InfoKind.support);
  factory InfoScreen.credits() => const InfoScreen._(_InfoKind.credits);

  final _InfoKind _kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.read(servicesProvider);
    final (title, body) = switch (_kind) {
      _InfoKind.privacy => (l.privacy, l.privacyBody),
      _InfoKind.support => (l.support, l.supportBody),
      _InfoKind.credits => (l.credits, l.creditsBody),
    };
    final recent = s.crash is LocalCrashReporter
        ? (s.crash as LocalCrashReporter).recent
        : const <String>[];
    const textStyle = TextStyle(
      color: AtelierColors.textOnLight,
      fontWeight: FontWeight.w700,
      height: 1.45,
      fontSize: 15,
    );
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      extendBodyBehindAppBar: true,
      body: AtelierBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(AtelierSpacing.md),
            children: [
              IvoryPanel(child: Text(body, style: textStyle)),
              if (_kind == _InfoKind.support) ...[
                const SizedBox(height: 12),
                IvoryPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.supportContactPending, style: textStyle),
                      const SizedBox(height: 8),
                      Text(l.appVersion(s.appVersion), style: textStyle),
                      Text(
                        'save ${ref.watch(saveHealthProvider).value?.name ?? '-'}',
                        style: const TextStyle(
                          color: AtelierColors.textOnLightMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                SectionTitle(l.recentIssues),
                IvoryPanel(
                  child: SelectableText(
                    recent.isEmpty ? l.noIssues : recent.join('\n'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AtelierColors.textOnLightMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
