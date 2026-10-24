// Renders every coin emblem at a large and a small size for visual review:
//   flutter test tool/render_emblem_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:coin/game/render/theme/coin_theme.dart';
import 'package:coin/game/render/theme/emblems.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('emblem preview', () async {
    final font = FontLoader('Fredoka')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/Fredoka.ttf').readAsBytesSync(),
          ),
        ),
      );
    await font.load();
    final emblems = Emblem.values.where((e) => e != Emblem.none).toList();
    const cols = 6;
    const cw = 220.0;
    const ch = 190.0;
    final rows = (emblems.length / cols).ceil();
    const w = cols * cw;
    final h = rows * ch;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF1C120B),
    );
    for (var i = 0; i < emblems.length; i++) {
      final e = emblems[i];
      final x = (i % cols) * cw;
      final y = (i ~/ cols) * ch;
      _draw(canvas, e, Offset(x + 75, y + 85), 60);
      _draw(canvas, e, Offset(x + 180, y + 120), 18);
      TextPainter(
          text: TextSpan(
            text: e.name,
            style: const TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 15,
              color: Color(0xFFE8D9C0),
            ),
          ),
          textDirection: TextDirection.ltr,
        )
        ..layout()
        ..paint(canvas, Offset(x + 140, y + 12));
    }
    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('build/emblem_preview.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// Draws [e] centred on [c], one unit = [r] px, over a faint coin disc.
void _draw(Canvas canvas, Emblem e, Offset c, double r) {
  canvas.drawCircle(c, r * 1.12, Paint()..color = const Color(0xFF3A2A1C));
  canvas.drawRect(
    Rect.fromCircle(center: c, radius: r * 0.9),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..color = const Color(0x44FFFFFF),
  );
  final m = Matrix4.identity()
    ..translateByDouble(c.dx, c.dy, 0, 1)
    ..scaleByDouble(r, r, 1, 1);
  final p = Emblems.path(e).transform(m.storage);
  final b = Rect.fromCircle(center: c, radius: r);
  canvas.drawPath(
    p,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFF0A8), Color(0xFFE0A930), Color(0xFF9A6410)],
      ).createShader(b),
  );
  canvas.drawPath(
    p,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r > 30 ? 1.6 : 0.9
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF3A1E05),
  );
}
