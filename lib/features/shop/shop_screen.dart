import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../application/billing/purchase_coordinator.dart';
import '../../application/ports/ports.dart';
import '../../application/providers.dart';
import '../../domain/economy/economy.dart';
import '../../domain/progression/player_profile.dart';
import '../../game/render/theme/coin_themes.dart';
import '../common/game_icons.dart';
import '../common/game_ui.dart';
import '../common/tab_page.dart';
import '../common/widgets.dart';

final _removeAdsProduct = FutureProvider<StoreProduct?>((ref) async {
  final billing = ref.watch(servicesProvider).billing;
  if (!billing.isAvailable) return null;
  final products = await billing.products({'remove_ads'});
  return products.isEmpty ? null : products.first;
});

/// Earned currency, optional rewarded video and real-money items are clearly
/// separated and labelled (design.md §5H).
class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  bool _watching = false;
  int _txSeq = 0;

  void _buy(ShopOffer offer) {
    final s = ref.read(servicesProvider);
    final now = s.clock.now();
    final r = Economy.buy(
      ref.read(saveProvider).profile,
      offer,
      txId: 'shop:${offer.name}:${now.microsecondsSinceEpoch}:${_txSeq++}',
      now: now,
    );
    if (!r.isOk) {
      showToast(context, context.l10n.notEnoughGilt);
      return;
    }
    ref.read(saveProvider.notifier).updateProfile((_) => r.profile);
    s.audio.play(Sfx.reward);
    showToast(context, context.l10n.purchasedItem);
  }

  Future<void> _watchForHint() async {
    final s = ref.read(servicesProvider);
    final l = context.l10n;
    setState(() => _watching = true);
    s.analytics.log(AnalyticsEvent.adRequested, {'placement': 'shop_hint'});
    final ready = await s.ads.isRewardedReady();
    if (!mounted) return;
    if (!ready) {
      setState(() => _watching = false);
      showToast(context, l.adUnavailable);
      return;
    }
    final result = await s.ads.showRewarded('shop_hint');
    if (!mounted) return;
    setState(() => _watching = false);
    switch (result.outcome) {
      case AdOutcome.completed:
        final r = Economy.grantItem(
          ref.read(saveProvider).profile,
          InventoryItem.hint,
          1,
          txId: 'ad:${result.token}',
        );
        if (r.isOk) {
          await ref.read(saveProvider.notifier).updateProfile((_) => r.profile);
          s.analytics.log(AnalyticsEvent.adCompleted, {
            'placement': 'shop_hint',
          });
          if (mounted) showToast(context, l.adRewarded);
        }
      case AdOutcome.dismissed:
        showToast(context, l.adDismissed);
      case AdOutcome.unavailable || AdOutcome.failed:
        s.analytics.log(AnalyticsEvent.adFailed, {'placement': 'shop_hint'});
        showToast(context, l.adUnavailable);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final profile = ref.watch(saveProvider.select((s) => s.profile));
    final s = ref.read(servicesProvider);
    ref.listen(purchaseCoordinatorProvider, (_, n) {
      if (n == null) return;
      final msg = switch (n.status) {
        PurchaseStatus.pending => l.purchasePending,
        PurchaseStatus.failed || PurchaseStatus.canceled => l.purchaseFailed,
        PurchaseStatus.restored => l.restoreDone,
        PurchaseStatus.purchased => l.removeAdsOwned,
        PurchaseStatus.refunded => null,
      };
      if (msg != null) showToast(context, msg);
    });
    final product = ref.watch(_removeAdsProduct);

    final hints = profile.count(InventoryItem.hint);
    final trays = profile.count(InventoryItem.bonusTray);
    final storeReady = !profile.removeAds && product.value != null;
    return TabPage(
      title: l.shopTitle,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
        children: [
          GameSectionTitle(l.shopEarnedSection),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _OfferCard(
                  glyph: GameGlyph.hint,
                  title: l.shopHintPack,
                  description: l.shopHintPackDesc,
                  owned: hints,
                  button: _GiltButton(
                    cost: ShopOffer.hintPack.cost,
                    affordable: profile.gilt >= ShopOffer.hintPack.cost,
                    onPressed: () => _buy(ShopOffer.hintPack),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _OfferCard(
                  glyph: GameGlyph.extraTray,
                  title: l.shopBonusTray,
                  description: l.shopBonusTrayDesc,
                  owned: trays,
                  button: _GiltButton(
                    cost: ShopOffer.bonusTray.cost,
                    affordable: profile.gilt >= ShopOffer.bonusTray.cost,
                    onPressed: () => _buy(ShopOffer.bonusTray),
                  ),
                ),
              ),
            ],
          ),
          GameSectionTitle(l.shopFreeSection),
          _WideOffer(
            glyph: GameGlyph.video,
            title: l.watchForHint,
            description: s.ads.isConfigured
                ? l.shopHintPackDesc
                : l.adUnavailable,
            button: GameButton(
              label: _watching ? '…' : l.watchForHint,
              tone: GameTone.blue,
              icon: GameGlyph.video,
              fontSize: 16,
              height: 48,
              onPressed: s.ads.isConfigured && !_watching
                  ? _watchForHint
                  : null,
            ),
          ),
          GameSectionTitle(l.shopStoreSection),
          _WideOffer(
            glyph: GameGlyph.noAds,
            title: l.removeAdsTitle,
            description: profile.removeAds ? l.removeAdsOwned : l.removeAdsDesc,
            button: GameButton(
              label: profile.removeAds
                  ? l.inUse
                  : (product.value?.priceLabel ?? l.unavailable),
              tone: GameTone.green,
              fontSize: 16,
              height: 48,
              onPressed: storeReady
                  ? () => ref
                        .read(purchaseCoordinatorProvider.notifier)
                        .buy('remove_ads')
                  : null,
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: s.billing.isAvailable
                ? GameButton(
                    label: l.restorePurchases,
                    tone: GameTone.walnut,
                    icon: GameGlyph.restart,
                    fontSize: 15,
                    height: 44,
                    onPressed: () => ref
                        .read(purchaseCoordinatorProvider.notifier)
                        .restore(),
                  )
                : Text(
                    l.storeUnavailable,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AtelierColors.textOnDarkMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Gold price button with the gilt coin; greyed (but still tappable, to
/// explain why) when the player can't afford it.
class _GiltButton extends StatelessWidget {
  const _GiltButton({
    required this.cost,
    required this.affordable,
    required this.onPressed,
  });

  final int cost;
  final bool affordable;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => GameButton(
    label: '$cost',
    tone: affordable ? GameTone.gold : GameTone.grey,
    leading: const CoinIcon(
      family: 'amber',
      size: 24,
      theme: CoinThemes.atelier,
    ),
    fontSize: 18,
    height: 46,
    expand: true,
    onPressed: onPressed,
  );
}

/// Shop tile: big icon on a glow, title, owned count and the price button.
class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.glyph,
    required this.title,
    required this.description,
    required this.owned,
    required this.button,
  });

  final GameGlyph glyph;
  final String title;
  final String description;
  final int owned;
  final Widget button;

  @override
  Widget build(BuildContext context) => GamePanel(
    padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
    child: Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0xFFFFF3B0), Color(0x00FFF3B0)],
                ),
              ),
              alignment: Alignment.center,
              child: GameIcon(glyph, size: 64),
            ),
            Positioned(
              right: -6,
              bottom: 4,
              child: NoticeBadge('×$owned', tone: GameTone.blue),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: AtelierFonts.display,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: AtelierColors.textOnLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AtelierColors.textOnLightMuted,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        button,
      ],
    ),
  );
}

/// Full-width offer: icon left, text, button underneath.
class _WideOffer extends StatelessWidget {
  const _WideOffer({
    required this.glyph,
    required this.title,
    required this.description,
    required this.button,
  });

  final GameGlyph glyph;
  final String title;
  final String description;
  final Widget button;

  @override
  Widget build(BuildContext context) => GamePanel(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
    child: Column(
      children: [
        Row(
          children: [
            GameIcon(glyph, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: AtelierFonts.display,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: AtelierColors.textOnLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AtelierColors.textOnLightMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerRight, child: button),
      ],
    ),
  );
}
