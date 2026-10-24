import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../application/ports/ports.dart';
import '../../application/providers.dart';
import '../../domain/economy/economy.dart';
import '../../domain/model/families.dart';
import '../common/names.dart';
import '../common/widgets.dart';

/// Collector's cabinet: discovered families and cosmetic finishes. Cosmetics
/// never change rules or odds.
class CabinetScreen extends ConsumerWidget {
  const CabinetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final profile = ref.watch(saveProvider.select((s) => s.profile));
    final colorBlind = ref.watch(
      saveProvider.select((s) => s.settings.colorBlind),
    );
    final s = ref.read(servicesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.cabinetTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GiltBadge(amount: profile.gilt),
          ),
        ],
      ),
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
              SectionTitle(l.cabinetFamilies),
              IvoryPanel(
                child: GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 0.72,
                  children: [
                    for (final f in CoinFamilies.all)
                      _FamilyCell(
                        family: f,
                        found: profile.discoveredFamilies.contains(f),
                        finish: profile.activeFinish,
                        colorBlind: colorBlind,
                      ),
                  ],
                ),
              ),
              SectionTitle(l.finishesTitle),
              Text(
                l.finishesNote,
                style: const TextStyle(
                  color: AtelierColors.textOnDarkMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              for (final f in CoinFinish.values) ...[
                IvoryPanel(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      for (final fam in const ['jade', 'ruby', 'sapphire'])
                        CoinIcon(
                          family: fam,
                          tier: fam == 'ruby' ? 2 : 1,
                          size: 44,
                          finish: f.name,
                          colorBlind: colorBlind,
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          finishDisplayName(context, f),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: AtelierColors.textOnLight),
                        ),
                      ),
                      _FinishAction(
                        owned: profile.ownedFinishes.contains(f.name),
                        active: profile.activeFinish == f.name,
                        cost: f.cost,
                        affordable: profile.gilt >= f.cost,
                        onUse: () => ref
                            .read(saveProvider.notifier)
                            .updateProfile(
                              (p) => p.copyWith(activeFinish: f.name),
                            ),
                        onBuy: () {
                          final r = Economy.buyFinish(
                            ref.read(saveProvider).profile,
                            f,
                            now: s.clock.now(),
                          );
                          if (!r.isOk) {
                            showToast(context, l.notEnoughGilt);
                            return;
                          }
                          ref
                              .read(saveProvider.notifier)
                              .updateProfile((_) => r.profile);
                          s.audio.play(Sfx.reward);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FamilyCell extends StatelessWidget {
  const _FamilyCell({
    required this.family,
    required this.found,
    required this.finish,
    required this.colorBlind,
  });

  final String family;
  final bool found;
  final String finish;
  final bool colorBlind;

  @override
  Widget build(BuildContext context) {
    final name = found
        ? familyDisplayName(context, family)
        : context.l10n.undiscovered;
    return Semantics(
      label: name,
      excludeSemantics: true,
      child: Column(
        children: [
          CoinIcon(
            family: family,
            size: 58,
            finish: finish,
            colorBlind: colorBlind,
            hidden: !found,
            dim: !found,
          ),
          const SizedBox(height: 4),
          Text(
            found ? name : '?',
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: found ? AtelierColors.textOnLight : AtelierColors.disabled,
            ),
          ),
        ],
      ),
    );
  }
}

class _FinishAction extends StatelessWidget {
  const _FinishAction({
    required this.owned,
    required this.active,
    required this.cost,
    required this.affordable,
    required this.onUse,
    required this.onBuy,
  });

  final bool owned;
  final bool active;
  final int cost;
  final bool affordable;
  final VoidCallback onUse;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final style = FilledButton.styleFrom(
      minimumSize: const Size(0, AtelierSpacing.tapTarget),
      foregroundColor: AtelierColors.textOnLight,
      textStyle: const TextStyle(
        fontFamily: AtelierFonts.display,
        fontWeight: FontWeight.w600,
      ),
    );
    if (active) {
      return Chip(
        label: Text(l.inUse),
        avatar: const Icon(Icons.check_rounded, size: 18),
        backgroundColor: const Color(0xFFDFF3EE),
        side: BorderSide.none,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          color: AtelierColors.primaryDeep,
        ),
      );
    }
    if (owned) {
      return FilledButton(
        style: style.copyWith(
          backgroundColor: const WidgetStatePropertyAll(AtelierColors.primary),
        ),
        onPressed: onUse,
        child: Text(l.useFinish),
      );
    }
    return FilledButton(
      style: style.copyWith(
        backgroundColor: WidgetStatePropertyAll(
          affordable ? AtelierColors.accent : const Color(0xFFD6CDBE),
        ),
      ),
      onPressed: onBuy,
      child: Text(l.buyForGilt(cost)),
    );
  }
}
