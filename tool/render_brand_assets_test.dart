// Renders the launcher icon and splash logo from the in-game coin art, so
// branding needs no external artwork. Run with:
//   flutter test tool/render_brand_assets_test.dart
// then tool/apply_brand_assets.sh to copy sizes into android/ and ios/.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:coin/app/theme/tokens.dart';
import 'package:coin/game/render/coin_art.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _write(
  String path,
  int size,
  void Function(Canvas c, double s) paint,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paint(canvas, size.toDouble());
  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

void main() {
  test('render brand assets', () async {
    await _write('assets/branding/icon_1024.png', 1024, (c, s) {
      final rect = Rect.fromLTWH(0, 0, s, s);
      c.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            Offset(s * 0.38, s * 0.3),
            s * 0.9,
            const [
              AtelierColors.backgroundGlow,
              AtelierColors.background,
              AtelierColors.backgroundDeep,
            ],
            const [0, 0.55, 1],
          ),
      );
      CoinArt.paintCoin(
        c,
        Offset(s / 2, s * 0.48),
        s * 0.34,
        family: 'jade',
        tier: 2,
        finish: 'gilded',
      );
    });
    await _write('assets/branding/splash_logo.png', 432, (c, s) {
      CoinArt.paintCoin(
        c,
        Offset(s / 2, s * 0.48),
        s * 0.3,
        family: 'jade',
        tier: 2,
        finish: 'gilded',
      );
    });
  });
}
