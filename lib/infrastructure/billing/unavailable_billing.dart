import 'dart:async';

import '../../application/ports/ports.dart';

/// Used until store products are configured. The shop shows "store
/// unavailable" rather than a fake price or a fake purchase.
final class UnavailableBilling implements BillingPort {
  final _updates = StreamController<PurchaseUpdate>.broadcast();

  @override
  bool get isAvailable => false;

  @override
  Future<List<StoreProduct>> products(Set<String> ids) async => const [];

  @override
  Future<void> buy(String productId) async =>
      throw StateError('Billing is not configured in this build');

  @override
  Future<void> restore() async {}

  @override
  Stream<PurchaseUpdate> get updates => _updates.stream;
}
