import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../application/ports/ports.dart';
import '../../application/providers.dart';
import '../chapter_map/chapter_map_screen.dart';
import '../collection/cabinet_screen.dart';
import '../common/game_icons.dart';
import '../common/game_ui.dart';
import '../common/widgets.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';
import '../shop/shop_screen.dart';
import '../themes/theme_screen.dart';

/// Bottom-bar tabs, left to right. Home sits in the raised centre slot.
enum ShellTab { shop, cabinet, home, map, themes }

final class ShellTabController extends Notifier<ShellTab> {
  @override
  ShellTab build() => ShellTab.home;

  void go(ShellTab tab) => state = tab;
}

final shellTabProvider = NotifierProvider<ShellTabController, ShellTab>(
  ShellTabController.new,
);

/// The hub every player returns to (game UI redesign §3): scenery, a top HUD
/// with gilt and settings, the active tab, and the bottom tab bar. Tabs keep
/// their state; Back on any tab but Home returns Home.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(shellTabProvider);
    final gilt = ref.watch(saveProvider.select((s) => s.profile.gilt));
    final ctrl = ref.read(shellTabProvider.notifier);
    return PopScope(
      canPop: tab == ShellTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ctrl.go(ShellTab.home);
      },
      child: Scaffold(
        body: AtelierBackground(
          child: Column(
            children: [
              SafeArea(
                bottom: false,
                child: _TopHud(gilt: gilt, onAdd: () => ctrl.go(ShellTab.shop)),
              ),
              Expanded(
                child: IndexedStack(
                  index: tab.index,
                  children: const [
                    ShopScreen(),
                    CabinetScreen(),
                    HomeScreen(),
                    ChapterMapScreen(),
                    ThemeScreen(),
                  ],
                ),
              ),
              ref.read(servicesProvider).ads.banner('shell_bottom'),
              _TabBar(selected: tab, onSelect: ctrl.go),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopHud extends ConsumerWidget {
  const _TopHud({required this.gilt, required this.onAdd});

  final int gilt;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
    child: Row(
      children: [
        CurrencyPill(amount: gilt, onAdd: onAdd),
        const Spacer(),
        GameRoundButton(
          icon: GameGlyph.settings,
          tooltip: context.l10n.settings,
          size: 44,
          onPressed: () {
            ref.read(servicesProvider).audio.play(Sfx.tap);
            showSettings(context);
          },
        ),
      ],
    ),
  );
}

class _TabBar extends ConsumerWidget {
  const _TabBar({required this.selected, required this.onSelect});

  final ShellTab selected;
  final ValueChanged<ShellTab> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final items = [
      (ShellTab.shop, GameGlyph.shop, l.shop),
      (ShellTab.cabinet, GameGlyph.cabinet, l.cabinet),
      (ShellTab.home, GameGlyph.home, l.tabHome),
      (ShellTab.map, GameGlyph.map, l.tabMap),
      (ShellTab.themes, GameGlyph.cities, l.themes),
    ];
    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6A3C1A), Color(0xFF3A1E0A)],
        ),
        border: Border(top: BorderSide(color: AtelierColors.accent, width: 3)),
        boxShadow: [
          BoxShadow(
            color: Color(0x88000000),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        height: 70,
        child: Row(
          children: [
            for (final (tab, glyph, label) in items)
              Expanded(
                flex: tab == selected ? 13 : 10,
                child: _TabItem(
                  glyph: glyph,
                  label: label,
                  selected: tab == selected,
                  onTap: () {
                    if (tab == selected) return;
                    ref.read(servicesProvider).audio.play(Sfx.tap);
                    HapticFeedback.selectionClick();
                    onSelect(tab);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.glyph,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final GameGlyph glyph;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        margin: EdgeInsets.fromLTRB(3, selected ? 0 : 8, 3, selected ? 4 : 6),
        decoration: selected
            ? BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFE07A), Color(0xFFE09A1C)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2A1407), width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x88000000),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              )
            : null,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // The selected icon pops up out of the bar.
            AnimatedPositioned(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              top: selected ? -18 : 2,
              child: GameIcon(glyph, size: selected ? 50 : 36),
            ),
            Positioned(
              bottom: 2,
              child: selected
                  ? StrokeText(label, size: 14)
                  : Text(
                      label,
                      style: const TextStyle(
                        fontFamily: AtelierFonts.display,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AtelierColors.textOnDarkMuted,
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
