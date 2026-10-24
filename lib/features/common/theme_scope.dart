import 'package:flutter/widgets.dart';

import '../../game/render/theme/coin_theme.dart';
import '../../game/render/theme/coin_themes.dart';

/// The player's selected look, available to every widget that paints coins
/// or scenery.
class CoinThemeScope extends InheritedWidget {
  const CoinThemeScope({
    super.key,
    required this.theme,
    this.reducedMotion = false,
    required super.child,
  });

  final CoinTheme theme;

  /// Player's reduced-motion setting, for ambient scenery.
  final bool reducedMotion;

  static CoinThemeScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CoinThemeScope>();

  static CoinTheme of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CoinThemeScope>()?.theme ??
      CoinThemes.atelier;

  @override
  bool updateShouldNotify(CoinThemeScope old) =>
      old.theme.id != theme.id || old.reducedMotion != reducedMotion;
}
