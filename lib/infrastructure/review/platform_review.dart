import 'package:in_app_review/in_app_review.dart';

import '../../application/ports/ports.dart';

/// Google Play In-App Review / StoreKit rating sheet. The platform applies
/// its own quota and may show nothing; that is expected.
final class PlatformReview implements ReviewPort {
  const PlatformReview();

  @override
  Future<void> request() async {
    final review = InAppReview.instance;
    if (await review.isAvailable()) await review.requestReview();
  }
}
