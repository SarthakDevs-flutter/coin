// Renders a strip of frames of a stack moving between two trays, for
// reviewing the 3D roll and the ribbon stagger:
//   flutter test tool/render_flight_preview_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:coin/domain/model/coin.dart';
import 'package:coin/game/components/coin_component.dart';
import 'package:coin/game/render/coin_sprite_cache.dart';
import 'package:coin/game/render/disc_art.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('flight preview', () async {
    const d = 90.0;
    const panelW = 420.0;
    const panelH = 420.0;
    const cols = 5;
    const frames = 15;
    final cache = CoinSpriteCache(pixelRatio: 1);
    final t = DiscArt.thickness(d);
    Vector2 slot(double x, int j) => Vector2(x, 360 - t - j * t);

    // Five coins leave tray A (top first) and land in tray B.
    const n = 5;
    final coins = [
      for (var j = 0; j < n; j++)
        CoinComponent(
          coin: CoinState(id: 'c$j', familyId: 'ruby', tier: 1),
          diameter: d,
          cache: cache,
          look: const CoinLook(finish: 'enamel', colorBlind: false),
          at: slot(110, 2 + j),
        ),
    ];
    final base = [
      for (var j = 0; j < 2; j++)
        CoinComponent(
          coin: CoinState(id: 'a$j', familyId: 'jade', tier: 1),
          diameter: d,
          cache: cache,
          look: const CoinLook(finish: 'enamel', colorBlind: false),
          at: slot(110, j),
        ),
      for (var j = 0; j < 1; j++)
        CoinComponent(
          coin: CoinState(id: 'b$j', familyId: 'ruby', tier: 1),
          diameter: d,
          cache: cache,
          look: const CoinLook(finish: 'enamel', colorBlind: false),
          at: slot(310, j),
        ),
    ];
    for (var k = 0; k < n; k++) {
      final c = coins[n - 1 - k];
      final target = slot(310, 1 + k);
      final dist = (target - c.position).length;
      c.flyTo(
        k * 0.034,
        target,
        (0.34 + dist / (d * 18)).clamp(0.36, 0.5).toDouble(),
        arc: d * 0.55 + dist * 0.16,
        flips: 1,
      );
    }

    final rows = (frames / cols).ceil();
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, panelW * cols, panelH * rows),
      Paint()..color = const Color(0xFF3B200D),
    );
    const dt = 1 / 60;
    var time = 0.0;
    for (var f = 0; f < frames; f++) {
      final target = f * 0.05;
      while (time < target) {
        for (final c in coins) {
          c.update(dt);
        }
        time += dt;
      }
      final ox = (f % cols) * panelW;
      final oy = (f ~/ cols) * panelH;
      canvas.save();
      canvas.translate(ox, oy);
      final all = [...base, ...coins]
        ..sort((a, b) => b.position.y.compareTo(a.position.y));
      for (final c in all) {
        canvas.save();
        canvas.translate(c.position.x, c.position.y);
        c.render(canvas);
        canvas.restore();
      }
      final tp = TextPainter(
        text: TextSpan(
          text: '${(target * 1000).round()} ms',
          style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, const Offset(8, 8));
      canvas.restore();
    }
    final img = await rec.endRecording().toImage(
      (panelW * cols).toInt(),
      (panelH * rows).toInt(),
    );
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('build/flight_preview.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
    expect(math.max(1, 0), 1);
  });
}
