import 'package:flutter/services.dart';

import '../../application/ports/ports.dart';

final class SystemHaptics implements HapticsPort {
  SystemHaptics(this._enabled);

  final bool Function() _enabled;

  @override
  void play(HapticKind kind) {
    if (!_enabled()) return;
    switch (kind) {
      case HapticKind.light:
        HapticFeedback.selectionClick();
      case HapticKind.medium:
        HapticFeedback.lightImpact();
      case HapticKind.success:
        HapticFeedback.mediumImpact();
      case HapticKind.warning:
        HapticFeedback.vibrate();
    }
  }
}
