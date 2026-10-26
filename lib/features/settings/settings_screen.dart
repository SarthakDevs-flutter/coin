import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/gen/app_localizations.dart';
import '../../app/theme/tokens.dart';
import '../../application/billing/purchase_coordinator.dart';
import '../../application/providers.dart';
import '../../application/session/gameplay_controller.dart';
import '../../application/state/settings.dart';
import '../common/game_icons.dart';
import '../common/game_ui.dart';
import '../common/widgets.dart';
import '../shell/app_shell.dart';
import '../support/info_screens.dart';

/// Whether the consent framework requires an "ad privacy choices" entry.
final _adPrivacyRequired = FutureProvider.autoDispose<bool>(
  (ref) => ref.read(servicesProvider).ads.privacyOptionsRequired(),
);

/// Opens settings as a game panel over the current screen.
Future<void> showSettings(BuildContext context) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: context.l10n.close,
  barrierColor: const Color(0xAA000000),
  transitionDuration: const Duration(milliseconds: 220),
  pageBuilder: (context, _, _) => const _SettingsPanel(),
  transitionBuilder: (context, a, _, child) => FadeTransition(
    opacity: a,
    child: ScaleTransition(
      scale: Tween(
        begin: 0.88,
        end: 1.0,
      ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)),
      child: child,
    ),
  ),
);

class _SettingsPanel extends ConsumerWidget {
  const _SettingsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final st = ref.watch(saveProvider.select((s) => s.settings));
    final save = ref.read(saveProvider.notifier);
    final billing = ref.read(servicesProvider).billing;
    void set(GameSettings Function(GameSettings) f) => save.updateSettings(f);
    void open(Widget page) => Navigator.of(context).push(atelierRoute(page));

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 440,
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GamePanel(
                  title: l.settings,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            _BigToggle(
                              glyph: GameGlyph.sound,
                              label: l.soundEffects,
                              value: st.sfx,
                              onChanged: (v) => set((s) => s.copyWith(sfx: v)),
                            ),
                            const SizedBox(width: 10),
                            _BigToggle(
                              glyph: GameGlyph.music,
                              label: l.music,
                              value: st.music,
                              onChanged: (v) =>
                                  set((s) => s.copyWith(music: v)),
                            ),
                            const SizedBox(width: 10),
                            _BigToggle(
                              glyph: GameGlyph.vibrate,
                              label: l.haptics,
                              value: st.haptics,
                              onChanged: (v) =>
                                  set((s) => s.copyWith(haptics: v)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _Row(
                          glyph: GameGlyph.motion,
                          title: l.reducedMotion,
                          subtitle: l.reducedMotionDesc,
                          trailing: GameToggle(
                            value: st.reducedMotion,
                            onChanged: (v) =>
                                set((s) => s.copyWith(reducedMotion: v)),
                          ),
                        ),
                        _Row(
                          glyph: GameGlyph.eye,
                          title: l.colorBlind,
                          subtitle: l.colorBlindDesc,
                          trailing: GameToggle(
                            value: st.colorBlind,
                            onChanged: (v) =>
                                set((s) => s.copyWith(colorBlind: v)),
                          ),
                        ),
                        _Row(
                          glyph: GameGlyph.language,
                          title: l.language,
                          trailing: DropdownButton<String?>(
                            value: st.localeCode,
                            underline: const SizedBox.shrink(),
                            dropdownColor: AtelierColors.surface,
                            style: const TextStyle(
                              fontFamily: AtelierFonts.display,
                              fontWeight: FontWeight.w600,
                              color: AtelierColors.textOnLight,
                            ),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text(l.systemLanguage),
                              ),
                              for (final loc
                                  in AppLocalizations.supportedLocales)
                                DropdownMenuItem(
                                  value: loc.languageCode,
                                  child: Text(loc.languageCode.toUpperCase()),
                                ),
                            ],
                            onChanged: (v) =>
                                set((s) => s.copyWith(localeCode: () => v)),
                          ),
                        ),
                        _Row(
                          glyph: GameGlyph.privacy,
                          title: l.analyticsConsent,
                          subtitle: l.analyticsConsentDesc,
                          trailing: GameToggle(
                            value: st.analyticsConsent,
                            onChanged: (v) =>
                                set((s) => s.copyWith(analyticsConsent: v)),
                          ),
                        ),
                        if (kDebugMode)
                          _Row(
                            glyph: GameGlyph.settings,
                            title: l.devOverlay,
                            trailing: GameToggle(
                              value: st.devOverlay,
                              onChanged: (v) =>
                                  set((s) => s.copyWith(devOverlay: v)),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            GameButton(
                              label: l.privacy,
                              icon: GameGlyph.privacy,
                              tone: GameTone.walnut,
                              fontSize: 14,
                              height: 42,
                              onPressed: () => open(InfoScreen.privacy()),
                            ),
                            if (ref.watch(_adPrivacyRequired).value ?? false)
                              GameButton(
                                label: l.adPrivacyChoices,
                                icon: GameGlyph.privacy,
                                tone: GameTone.walnut,
                                fontSize: 14,
                                height: 42,
                                onPressed: () => ref
                                    .read(servicesProvider)
                                    .ads
                                    .showPrivacyOptions(),
                              ),
                            GameButton(
                              label: l.support,
                              icon: GameGlyph.help,
                              tone: GameTone.walnut,
                              fontSize: 14,
                              height: 42,
                              onPressed: () => open(InfoScreen.support()),
                            ),
                            GameButton(
                              label: l.credits,
                              icon: GameGlyph.star,
                              tone: GameTone.walnut,
                              fontSize: 14,
                              height: 42,
                              onPressed: () => open(InfoScreen.credits()),
                            ),
                            if (billing.isAvailable)
                              GameButton(
                                label: l.restorePurchases,
                                icon: GameGlyph.restart,
                                tone: GameTone.walnut,
                                fontSize: 14,
                                height: 42,
                                onPressed: () => ref
                                    .read(purchaseCoordinatorProvider.notifier)
                                    .restore(),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        GameButton(
                          label: l.resetProgress,
                          tone: GameTone.red,
                          fontSize: 14,
                          height: 40,
                          onPressed: () async {
                            final ok = await confirmDialog(
                              context,
                              title: l.resetConfirmTitle,
                              body: l.resetConfirmBody,
                              confirm: l.resetConfirmAction,
                              destructive: true,
                            );
                            if (!ok) return;
                            ref.invalidate(gameplayProvider);
                            await save.resetProgress();
                            ref
                                .read(shellTabProvider.notifier)
                                .go(ShellTab.home);
                            if (context.mounted) {
                              Navigator.of(context).popUntil((r) => r.isFirst);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: -6,
                  top: 10,
                  child: GameRoundButton(
                    icon: GameGlyph.close,
                    tone: GameTone.red,
                    size: 42,
                    tooltip: l.close,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Square on/off tile for the three most-used switches.
class _BigToggle extends StatelessWidget {
  const _BigToggle({
    required this.glyph,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final GameGlyph glyph;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      toggled: value,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: value
                  ? [GameTone.blue.ramp[0], GameTone.blue.ramp[2]]
                  : const [Color(0xFFCFC6B6), Color(0xFF9C9384)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2A1407), width: 2),
            boxShadow: [
              BoxShadow(
                color: value ? GameTone.blue.lip : GameTone.grey.lip,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GameIcon(glyph, size: 40),
                  if (!value)
                    const Positioned.fill(
                      child: GameIcon(GameGlyph.close, size: 40),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: StrokeText(label, size: 13),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.glyph,
    required this.title,
    required this.trailing,
    this.subtitle,
  });

  final GameGlyph glyph;
  final String title;
  final String? subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        GameIcon(glyph, size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: AtelierFonts.display,
                  fontWeight: FontWeight.w600,
                  fontSize: 15.5,
                  color: AtelierColors.textOnLight,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    height: 1.25,
                    color: AtelierColors.textOnLightMuted,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    ),
  );
}
