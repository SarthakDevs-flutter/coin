// Renders every currency theme's coins, flat and stacked, for review:
//   flutter test tool/render_theme_coins_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:coin/domain/model/families.dart';
import 'package:coin/game/render/coin_art.dart';
import 'package:coin/game/render/disc_art.dart';
import 'package:coin/game/render/theme/coin_themes.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('theme coins preview', () async {
    for (final (name, file) in const [
      ('Fredoka', 'assets/fonts/Fredoka.ttf'),
      ('Nunito', 'assets/fonts/Nunito.ttf'),
    ]) {
      final font = FontLoader(name)
        ..addFont(
          Future.value(ByteData.sublistView(File(file).readAsBytesSync())),
        );
      await font.load();
    }
    final themes = CoinThemes.all;
    const d = 100.0;
    const rowH = 300.0;
    const w = 1240.0;
    final h = rowH * themes.length;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF1C120B),
    );
    for (final (ti, theme) in themes.indexed) {
      final y0 = ti * rowH;
      final tp = TextPainter(
        text: TextSpan(
          text: theme.name,
          style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 16),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(8, y0 + 4));
      for (final (i, f) in CoinFamilies.all.indexed) {
        final x = 75.0 + i * 150;
        CoinArt.paintCoin(
          canvas,
          Offset(x, y0 + 80),
          52,
          family: f,
          tier: i == 6 ? 2 : (i == 7 ? 3 : 1),
          theme: theme,
        );
        // A stack: three of the family under one of the next family.
        final base = y0 + 270;
        DiscArt.paintShadow(canvas, Offset(x, base), d);
        for (var j = 0; j < 4; j++) {
          final fam = j == 3
              ? CoinFamilies.all[(i + 1) % CoinFamilies.all.length]
              : f;
          DiscArt.paint(
            canvas,
            Offset(x, base - j * DiscArt.thickness(d)),
            d,
            family: fam,
            tier: 1,
            theme: theme,
          );
        }
      }
    }
    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('build/theme_coins_preview.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
