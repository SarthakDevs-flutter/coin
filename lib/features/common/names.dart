import 'package:flutter/widgets.dart';

import '../../domain/economy/economy.dart';
import 'theme_scope.dart';
import 'widgets.dart';

/// The family's name, or its denomination in a currency theme.
String familyDisplayName(BuildContext context, String id) {
  final coin = CoinThemeScope.of(context).coin(id);
  if (coin != null) return coin.name;
  final l = context.l10n;
  return switch (id) {
    'jade' => l.familyJade,
    'ruby' => l.familyRuby,
    'sapphire' => l.familySapphire,
    'amber' => l.familyAmber,
    'amethyst' => l.familyAmethyst,
    'pearl' => l.familyPearl,
    'onyx' => l.familyOnyx,
    'coral' => l.familyCoral,
    _ => id,
  };
}

String finishDisplayName(BuildContext context, CoinFinish f) {
  final l = context.l10n;
  return switch (f) {
    CoinFinish.enamel => l.finishEnamel,
    CoinFinish.satin => l.finishSatin,
    CoinFinish.gilded => l.finishGilded,
  };
}
