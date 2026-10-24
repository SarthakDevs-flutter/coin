// Renders a coin and disc-stack preview for visual review:
//   flutter test tool/render_disc_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:coin/domain/model/families.dart';
import 'package:coin/game/render/coin_art.dart';
import 'package:coin/game/render/disc_art.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disc preview', () async {
    final font = FontLoader('Fredoka')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/Fredoka.ttf').readAsBytesSync(),
          ),
        ),
      );
    await font.load();
    const d = 120.0;
    const w = 1300.0;
    const h = 900.0;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF1C120B),
    );
    // Flat coins: tier 1, tier 2, tier 3 rows.
    for (var i = 0; i < CoinFamilies.all.length; i++) {
      final f = CoinFamilies.all[i];
      final x = 80.0 + i * 150;
      for (var tier = 1; tier <= 3; tier++) {
        CoinArt.paintCoin(
          canvas,
          Offset(x, 70.0 + (tier - 1) * 130),
          58,
          family: f,
          tier: tier,
          finish: tier == 3 ? 'gilded' : 'enamel',
        );
      }
    }
    for (var i = 0; i < CoinFamilies.all.length; i++) {
      final f = CoinFamilies.all[i];
      final x = 80.0 + i * 150;
      const base = 820.0;
      DiscArt.paintShadow(canvas, Offset(x, base), d);
      final n = 4 + i % 4;
      for (var j = 0; j < n; j++) {
        final last = j == n - 1;
        DiscArt.paint(
          canvas,
          Offset(x, base - j * DiscArt.thickness(d)),
          d,
          family: f,
          tier: last && i.isOdd ? 2 : 1,
          hidden: j == 1 && i == 2,
          frost: last && i == 5 ? 2 : 0,
        );
      }
    }
    CoinArt.paintCoin(
      canvas,
      const Offset(1220, 400),
      50,
      family: 'ruby',
      tier: 1,
      hidden: true,
    );
    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('build/disc_preview.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
