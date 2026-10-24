import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/economy/economy.dart';
import '../ports/ports.dart';
import '../providers.dart';

/// Last purchase status for UI feedback.
final class PurchaseNotice {
  const PurchaseNotice(this.status, this.serial);
  final PurchaseStatus status;
  final int serial;
}

/// Flow J: listens to store updates and applies entitlements idempotently.
/// Pending is never treated as owned.
final purchaseCoordinatorProvider =
    NotifierProvider<PurchaseCoordinator, PurchaseNotice?>(
      PurchaseCoordinator.new,
    );

final class PurchaseCoordinator extends Notifier<PurchaseNotice?> {
  StreamSubscription<PurchaseUpdate>? _sub;
  int _serial = 0;

  @override
  PurchaseNotice? build() {
    final s = ref.watch(servicesProvider);
    _sub = s.billing.updates.listen(_onUpdate);
    ref.onDispose(() => _sub?.cancel());
    return null;
  }

  Future<void> buy(String productId) async {
    final s = ref.read(servicesProvider);
    s.analytics.log(AnalyticsEvent.purchaseStarted, {'product': productId});
    try {
      await s.billing.buy(productId);
    } on Object catch (e, stack) {
      s.crash.record(e, stack, context: {'where': 'purchase'});
      s.analytics.log(AnalyticsEvent.purchaseFailed, {'product': productId});
      state = PurchaseNotice(PurchaseStatus.failed, ++_serial);
    }
  }

  Future<void> restore() async {
    final s = ref.read(servicesProvider);
    await s.billing.restore();
    state = PurchaseNotice(PurchaseStatus.restored, ++_serial);
  }

  void _onUpdate(PurchaseUpdate u) {
    final s = ref.read(servicesProvider);
    final save = ref.read(saveProvider.notifier);
    final profile = ref.read(saveProvider).profile;
    switch (u.status) {
      case PurchaseStatus.purchased || PurchaseStatus.restored:
        final r = Economy.applyEntitlement(
          profile,
          u.productId,
          txId: u.transactionId,
        );
        if (r.isOk) save.updateProfile((_) => r.profile);
        s.analytics.log(
          u.status == PurchaseStatus.restored
              ? AnalyticsEvent.purchaseRestored
              : AnalyticsEvent.purchaseCompleted,
          {'product': u.productId},
        );
      case PurchaseStatus.refunded:
        if (u.productId == 'remove_ads') {
          save.updateProfile((p) => p.copyWith(removeAds: false));
        }
      case PurchaseStatus.failed || PurchaseStatus.canceled:
        s.analytics.log(AnalyticsEvent.purchaseFailed, {
          'product': u.productId,
          'status': u.status.name,
        });
      case PurchaseStatus.pending:
        break;
    }
    state = PurchaseNotice(u.status, ++_serial);
  }
}
