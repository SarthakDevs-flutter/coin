import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/gen/app_localizations.dart';
import '../../app/theme/tokens.dart';
import '../../application/billing/purchase_coordinator.dart';
import '../../application/providers.dart';
import '../../application/session/gameplay_controller.dart';
import '../../application/state/settings.dart';
import '../../domain/model/families.dart';
import '../../game/render/theme/coin_themes.dart';
import '../common/widgets.dart';
import '../support/info_screens.dart';
import '../themes/theme_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final st = ref.watch(saveProvider.select((s) => s.settings));
    final save = ref.read(saveProvider.notifier);
    final billing = ref.read(servicesProvider).billing;
    void set(GameSettings Function(GameSettings) f) => save.updateSettings(f);

    Widget toggle(
      String title,
      bool value,
      ValueChanged<bool> onChanged, {
      String? subtitle,
    }) => SwitchListTile.adaptive(
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: AtelierColors.textOnLight,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AtelierColors.textOnLightMuted,
              ),
            ),
      value: value,
      onChanged: onChanged,
    );

    Widget link(
      IconData icon,
      String title,
      VoidCallback onTap, {
      Color? color,
    }) => ListTile(
      minTileHeight: AtelierSpacing.tapTarget + 8,
      leading: Icon(icon, color: color ?? AtelierColors.accentDeep),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: color ?? AtelierColors.textOnLight,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AtelierColors.textOnLightMuted,
      ),
      onTap: onTap,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      extendBodyBehindAppBar: true,
      body: AtelierBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AtelierSpacing.md,
              0,
              AtelierSpacing.md,
              32,
            ),
            children: [
              SectionTitle(l.themes),
              IvoryPanel(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: CoinIcon(family: CoinFamilies.all.first, size: 40),
                  title: Text(
                    CoinThemes.byId(st.themeId).name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AtelierColors.textOnLight,
                    ),
                  ),
                  subtitle: Text(
                    CoinThemes.byId(st.themeId).currency,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AtelierColors.textOnLightMuted,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AtelierColors.textOnLight,
                  ),
                  onTap: () =>
                      Navigator.of(context)
                          .push(atelierRoute(const ThemeScreen())),
                ),
              ),
              SectionTitle(l.settingsAudio),
              IvoryPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    toggle(
                      l.soundEffects,
                      st.sfx,
                      (v) => set((s) => s.copyWith(sfx: v)),
                    ),
                    toggle(
                      l.music,
                      st.music,
                      (v) => set((s) => s.copyWith(music: v)),
                    ),
                    toggle(
                      l.haptics,
                      st.haptics,
                      (v) => set((s) => s.copyWith(haptics: v)),
                    ),
                  ],
                ),
              ),
              SectionTitle(l.settingsAccess),
              IvoryPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    toggle(
                      l.reducedMotion,
                      st.reducedMotion,
                      (v) => set((s) => s.copyWith(reducedMotion: v)),
                      subtitle: l.reducedMotionDesc,
                    ),
                    toggle(
                      l.colorBlind,
                      st.colorBlind,
                      (v) => set((s) => s.copyWith(colorBlind: v)),
                      subtitle: l.colorBlindDesc,
                    ),
                    ListTile(
                      title: Text(
                        l.language,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AtelierColors.textOnLight,
                        ),
                      ),
                      trailing: DropdownButton<String?>(
                        value: st.localeCode,
                        underline: const SizedBox.shrink(),
                        dropdownColor: AtelierColors.surface,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AtelierColors.textOnLight,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(l.systemLanguage),
                          ),
                          for (final loc in AppLocalizations.supportedLocales)
                            DropdownMenuItem(
                              value: loc.languageCode,
                              child: Text(loc.languageCode.toUpperCase()),
                            ),
                        ],
                        onChanged: (v) =>
                            set((s) => s.copyWith(localeCode: () => v)),
                      ),
                    ),
                  ],
                ),
              ),
              SectionTitle(l.settingsPrivacy),
              IvoryPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    toggle(
                      l.analyticsConsent,
                      st.analyticsConsent,
                      (v) => set((s) => s.copyWith(analyticsConsent: v)),
                      subtitle: l.analyticsConsentDesc,
                    ),
                    link(
                      Icons.privacy_tip_rounded,
                      l.privacy,
                      () =>
                          Navigator.of(context)
                              .push(atelierRoute(InfoScreen.privacy())),
                    ),
                    link(
                      Icons.support_agent_rounded,
                      l.support,
                      () =>
                          Navigator.of(context)
                              .push(atelierRoute(InfoScreen.support())),
                    ),
                    link(
                      Icons.favorite_rounded,
                      l.credits,
                      () =>
                          Navigator.of(context)
                              .push(atelierRoute(InfoScreen.credits())),
                    ),
                    if (billing.isAvailable)
                      link(
                        Icons.restore_rounded,
                        l.restorePurchases,
                        () => ref
                            .read(purchaseCoordinatorProvider.notifier)
                            .restore(),
                      ),
                  ],
                ),
              ),
              if (kDebugMode) ...[
                const SectionTitle('Debug'),
                IvoryPanel(
                  padding: EdgeInsets.zero,
                  child: toggle(
                    l.devOverlay,
                    st.devOverlay,
                    (v) => set((s) => s.copyWith(devOverlay: v)),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              IvoryPanel(
                padding: EdgeInsets.zero,
                child: link(
                  Icons.delete_forever_rounded,
                  l.resetProgress,
                  () async {
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
                    if (context.mounted) {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    }
                  },
                  color: AtelierColors.danger,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
