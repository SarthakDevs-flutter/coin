import 'package:coin/application/state/settings.dart';
import 'package:coin/domain/model/families.dart';
import 'package:coin/game/render/coin_art.dart';
import 'package:coin/game/render/currency_art.dart';
import 'package:coin/game/render/theme/coin_theme.dart';
import 'package:coin/game/render/theme/coin_themes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every currency theme covers every family with a distinct value', () {
    for (final t in CoinThemes.all.where((t) => t.isCurrency)) {
      final values = {
        for (final f in CoinFamilies.all) t.coin(f)?.value,
      };
      expect(values.contains(null), isFalse, reason: t.id);
      expect(values.length, CoinFamilies.all.length, reason: t.id);
    }
  });

  test('theme ids are unique and unknown ids fall back to the atelier', () {
    final ids = CoinThemes.all.map((t) => t.id).toSet();
    expect(ids.length, CoinThemes.all.length);
    expect(CoinThemes.byId('nope').id, CoinThemes.atelierId);
    expect(CoinThemes.byId(null).id, CoinThemes.atelierId);
    expect(CoinThemes.byId('japan'), same(CoinThemes.japan));
  });

  test('settings persist the theme and default old saves to the atelier', () {
    final s = const GameSettings().copyWith(themeId: 'india');
    expect(GameSettings.fromJson(s.toJson()).themeId, 'india');
    expect(GameSettings.fromJson(const {}).themeId, CoinThemes.atelierId);
  });

  test('currency styles derive from the outer metal', () {
    final s = CoinArt.style('sapphire', CoinThemes.europe);
    expect(s.metal, same(Metal.brass));
    expect(CoinArt.style('sapphire').metal, isNull);
  });

  test('shapes stay inside the unit circle and touch it', () {
    for (final shape in CoinShape.values) {
      var max = 0.0;
      for (var i = 0; i < 720; i++) {
        final r = CurrencyArt.rho(shape, i * 0.00872664626);
        expect(r, inInclusiveRange(0.85, 1.0 + 1e-9), reason: '$shape');
        if (r > max) max = r;
      }
      expect(max, closeTo(1, 0.01), reason: '$shape');
    }
  });
}
