import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../application/ports/ports.dart';
import '../../application/providers.dart';
import '../../domain/economy/economy.dart';
import '../../domain/progression/progression.dart';
import '../chapter_map/chapter_map_screen.dart';
import '../collection/cabinet_screen.dart';
import '../common/widgets.dart';
import '../gameplay/gameplay_screen.dart';
import '../settings/settings_screen.dart';
import '../shop/shop_screen.dart';
import '../themes/theme_screen.dart';

/// Continue is dominant; everything else is secondary (design.md §5C).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static String chapterName(BuildContext context, int chapter) {
    final l = context.l10n;
    return switch (chapter) {
      1 => l.chapter1,
      2 => l.chapter2,
      3 => l.chapter3,
      4 => l.chapter4,
      5 => l.chapter5,
      6 => l.chapter6,
      7 => l.chapter7,
      8 => l.chapter8,
      9 => l.chapter9,
      10 => l.chapter10,
      11 => l.chapter11,
      12 => l.chapter12,
      13 => l.chapter13,
      14 => l.chapter14,
      15 => l.chapter15,
      16 => l.chapter16,
      17 => l.chapter17,
      _ => l.chapterN(chapter),
    };
  }

  static String chapterDesc(BuildContext context, int chapter) {
    final l = context.l10n;
    return switch (chapter) {
      1 => l.chapter1Desc,
      2 => l.chapter2Desc,
      3 => l.chapter3Desc,
      4 => l.chapter4Desc,
      5 => l.chapter5Desc,
      6 => l.chapter6Desc,
      7 => l.chapter7Desc,
      8 => l.chapter8Desc,
      9 => l.chapter9Desc,
      10 => l.chapter10Desc,
      11 => l.chapter11Desc,
      12 => l.chapter12Desc,
      13 => l.chapter13Desc,
      14 => l.chapter14Desc,
      15 => l.chapter15Desc,
      16 => l.chapter16Desc,
      17 => l.chapter17Desc,
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context).textTheme;
    final pack = ref.watch(packProvider);
    final save = ref.watch(saveProvider);
    final profile = save.profile;
    final activeId = save.activeSession?['levelId'] as String?;
    final current =
        (activeId == null ? null : pack.byId(activeId)) ??
        Progression.currentLevel(pack, profile);
    final chapter = current.chapter;
    final done = Progression.completedInChapter(pack, profile, chapter);
    final total = pack.chapter(chapter).length;
    final allDone = Progression.campaignComplete(pack, profile);
    final now = ref.read(servicesProvider).clock.now();
    final giftReady = Economy.stipendAvailable(profile, now);

    void go(Widget page) => Navigator.of(context).push(atelierRoute(page));

    return Scaffold(
      body: AtelierBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AtelierSpacing.md,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        GiltBadge(amount: profile.gilt),
                        const Spacer(),
                        BarButton(
                          icon: Icons.settings_rounded,
                          tooltip: l.settings,
                          onPressed: () => go(const SettingsScreen()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const BrandMark(size: 96),
                    const SizedBox(height: 14),
                    Text(l.appTitle, style: theme.displayMedium),
                    const SizedBox(height: 28),
                    IvoryPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.chapterN(chapter).toUpperCase(),
                            style: const TextStyle(
                              fontFamily: AtelierFonts.display,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w600,
                              color: AtelierColors.accentDeep,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            chapterName(context, chapter),
                            style: theme.headlineMedium?.copyWith(
                              color: AtelierColors.textOnLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            chapterDesc(context, chapter),
                            style: const TextStyle(
                              color: AtelierColors.textOnLightMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: total == 0 ? 0 : done / total,
                              minHeight: 10,
                              color: AtelierColors.primary,
                              backgroundColor: const Color(0xFFEADBC0),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l.chapterProgress(done, total),
                            style: const TextStyle(
                              color: AtelierColors.textOnLightMuted,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    PrimaryButton(
                      large: true,
                      icon: Icons.play_arrow_rounded,
                      label: l.continueButton,
                      subtitle: l.levelN(current.number),
                      onPressed: () => go(GameplayScreen(levelId: current.id)),
                    ),
                    if (allDone) ...[
                      const SizedBox(height: 12),
                      Text(
                        l.campaignComplete,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AtelierColors.accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        RoundAction(
                          icon: Icons.map_rounded,
                          label: l.chapters,
                          onPressed: () => go(const ChapterMapScreen()),
                        ),
                        RoundAction(
                          icon: Icons.auto_awesome_mosaic_rounded,
                          label: l.cabinet,
                          onPressed: () => go(const CabinetScreen()),
                        ),
                        RoundAction(
                          icon: Icons.public_rounded,
                          label: l.themes,
                          onPressed: () => go(const ThemeScreen()),
                        ),
                        RoundAction(
                          icon: Icons.storefront_rounded,
                          label: l.shop,
                          onPressed: () => go(const ShopScreen()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    _DailyGift(ready: giftReady),
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

class _DailyGift extends ConsumerWidget {
  const _DailyGift({required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final s = ref.read(servicesProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0x22000000),
        borderRadius: const BorderRadius.all(AtelierRadii.md),
        border: Border.all(color: const Color(0x33FFF8EA)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.redeem_rounded,
            color: AtelierColors.accent,
            size: 30,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.dailyGift,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (!ready)
                  Text(
                    l.giftClaimed,
                    style: const TextStyle(
                      color: AtelierColors.textOnDarkMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          if (ready)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AtelierColors.primary,
                foregroundColor: AtelierColors.textOnLight,
                minimumSize: const Size(0, AtelierSpacing.tapTarget),
                textStyle: const TextStyle(
                  fontFamily: AtelierFonts.display,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              onPressed: () {
                final r = Economy.claimStipend(
                  ref.read(saveProvider).profile,
                  now: s.clock.now(),
                );
                if (!r.isOk) return;
                ref.read(saveProvider.notifier).updateProfile((_) => r.profile);
                s.audio.play(Sfx.reward);
              },
              child: Text(l.claimGilt(Economy.stipendAmount)),
            ),
        ],
      ),
    );
  }
}
