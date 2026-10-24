import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/tokens.dart';
import '../../application/billing/purchase_coordinator.dart';
import '../../application/ports/ports.dart';
import '../../application/providers.dart';
import '../../domain/economy/economy.dart';
import '../../domain/progression/player_profile.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(l.shopTitle),
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
              SectionTitle(l.shopEarnedSection),
              _OfferTile(
                icon: Icons.lightbulb_rounded,
                title: l.shopHintPack,
                description: l.shopHintPackDesc,
                owned: l.owned(profile.count(InventoryItem.hint)),
                action: l.buyForGilt(ShopOffer.hintPack.cost),
                affordable: profile.gilt >= ShopOffer.hintPack.cost,
                onPressed: () => _buy(ShopOffer.hintPack),
              ),
              const SizedBox(height: 12),
              _OfferTile(
                icon: Icons.add_box_rounded,
                title: l.shopBonusTray,
                description: l.shopBonusTrayDesc,
                owned: l.owned(profile.count(InventoryItem.bonusTray)),
                action: l.buyForGilt(ShopOffer.bonusTray.cost),
                affordable: profile.gilt >= ShopOffer.bonusTray.cost,
                onPressed: () => _buy(ShopOffer.bonusTray),
              ),
              SectionTitle(l.shopFreeSection),
              _OfferTile(
                icon: Icons.ondemand_video_rounded,
                title: l.watchForHint,
                description: s.ads.isConfigured
                    ? l.shopHintPackDesc
                    : l.adUnavailable,
                action: s.ads.isConfigured ? l.watchForHint : l.unavailable,
                busy: _watching,
                affordable: s.ads.isConfigured,
                onPressed: s.ads.isConfigured ? _watchForHint : null,
              ),
              SectionTitle(l.shopStoreSection),
              _OfferTile(
                icon: Icons.block_rounded,
                title: l.removeAdsTitle,
                description: profile.removeAds
                    ? l.removeAdsOwned
                    : l.removeAdsDesc,
                action: profile.removeAds
                    ? l.inUse
                    : (product.value?.priceLabel ?? l.unavailable),
                affordable: !profile.removeAds && product.value != null,
                onPressed: !profile.removeAds && product.value != null
                    ? () => ref
                          .read(purchaseCoordinatorProvider.notifier)
                          .buy('remove_ads')
                    : null,
              ),
              const SizedBox(height: 12),
              Center(
                child: s.billing.isAvailable
                    ? TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AtelierColors.textOnDark,
                        ),
                        onPressed: () => ref
                            .read(purchaseCoordinatorProvider.notifier)
                            .restore(),
                        icon: const Icon(Icons.restore_rounded),
                        label: Text(l.restorePurchases),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          l.storeUnavailable,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AtelierColors.textOnDarkMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
    required this.onPressed,
    this.owned,
    this.affordable = true,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? owned;
  final String action;
  final bool affordable;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IvoryPanel(
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: Color(0xFFF2E2C4),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AtelierColors.accentDeep, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: AtelierColors.textOnLight),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  color: AtelierColors.textOnLightMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              if (owned != null) ...[
                const SizedBox(height: 4),
                Text(
                  owned!,
                  style: const TextStyle(
                    color: AtelierColors.primaryDeep,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 120),
          child: onPressed == null && !busy
              // Unavailable: readable status chip, not a faded button.
              ? Container(
                  constraints: const BoxConstraints(
                    minHeight: AtelierSpacing.tapTarget,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9DFCB),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    action,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: AtelierFonts.display,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AtelierColors.textOnLightMuted,
                    ),
                  ),
                )
              : FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: affordable
                        ? AtelierColors.primary
                        : const Color(0xFFD6CDBE),
                    foregroundColor: AtelierColors.textOnLight,
                    minimumSize: const Size(0, AtelierSpacing.tapTarget),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: const TextStyle(
                      fontFamily: AtelierFonts.display,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  onPressed: busy ? null : onPressed,
                  child: busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Text(action, textAlign: TextAlign.center),
                ),
        ),
      ],
    ),
  );
}
