// Renders every theme backdrop side by side (with a still frame of its
// ambient particles on top) for visual review, and times each scene:
//   flutter test tool/render_scene_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:coin/features/common/scene_backdrop.dart';
import 'package:coin/game/render/theme/coin_themes.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scene preview', () async {
    const size = Size(400, 870);
    final themes = CoinThemes.all;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    // Warm up so the timings below exclude first-use setup.
    for (final t in themes) {
      final r = ui.PictureRecorder();
      SceneArt.paint(Canvas(r), size, t.scene);
      await r.endRecording().toImage(400, 870);
    }
    for (var i = 0; i < themes.length; i++) {
      final scene = themes[i].scene;
      // Time the work the app does once per size/theme: paint + rasterise.
      final sw = Stopwatch()..start();
      final r = ui.PictureRecorder();
      SceneArt.paint(Canvas(r), size, scene);
      final img = await r.endRecording().toImage(400, 870);
      sw.stop();
      // ignore: avoid_print
      print(
        '${scene.kind.name.padRight(10)} ${sw.elapsedMicroseconds / 1000} ms',
      );
      canvas
        ..save()
        ..translate(i * size.width, 0)
        ..drawImage(img, Offset.zero, Paint());
      AmbientLayer.paintFrame(canvas, size, scene.ambient, 6.3);
      canvas.restore();
    }
    final w = (size.width * themes.length).toInt();
    final out = await rec.endRecording().toImage(w, size.height.toInt());
    final bytes = await out.toByteData(format: ui.ImageByteFormat.png);
    File('build/scene_preview.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());

    // Landscape phone and tablet sizes, to check anchoring and scaling.
    const sizes = [Size(870, 400), Size(1200, 800)];
    final wide = ui.PictureRecorder();
    final wc = Canvas(wide);
    for (var i = 0; i < themes.length; i++) {
      var x = 0.0;
      for (final s in sizes) {
        wc
          ..save()
          ..translate(x, i * 800.0)
          ..clipRect(Offset.zero & s);
        SceneArt.paint(wc, s, themes[i].scene);
        AmbientLayer.paintFrame(wc, s, themes[i].scene.ambient, 6.3);
        wc.restore();
        x += s.width + 10;
      }
    }
    final wimg = await wide.endRecording().toImage(2080, 800 * themes.length);
    final wbytes = await wimg.toByteData(format: ui.ImageByteFormat.png);
    File('build/scene_preview_wide.png')
        .writeAsBytesSync(wbytes!.buffer.asUint8List());
  });
}
