// Renders a small board per theme with wells and stacks, for review:
//   flutter test tool/render_board_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:coin/domain/model/families.dart';
import 'package:coin/game/components/board_frame_component.dart';
import 'package:coin/game/components/tray_component.dart';
import 'package:coin/game/render/disc_art.dart';
import 'package:coin/game/render/theme/coin_themes.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('board preview', () async {
    final font = FontLoader('Fredoka')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('assets/fonts/Fredoka.ttf').readAsBytesSync(),
          ),
        ),
      );
    await font.load();
    const d = 70.0;
    const panelW = 420.0;
    const panelH = 360.0;
    final themes = CoinThemes.all;
    final w = panelW * 2;
    final h = panelH * ((themes.length + 1) ~/ 2);
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF101010),
    );
    for (final (ti, t) in themes.indexed) {
      final o = Offset((ti % 2) * panelW, (ti ~/ 2) * panelH);
      final board = Rect.fromLTWH(o.dx + 20, o.dy + 20, panelW - 40, 320);
      BoardFrameComponent.paintBoard(canvas, board, d, t.board);
      const cap = 5;
      final wellH = d * 0.16 + DiscArt.thickness(d) * (cap + 1) + d * 0.6;
      for (var i = 0; i < 4; i++) {
        final r = Rect.fromLTWH(
          board.left + 26 + i * (d * 1.3),
          board.top + 50,
          d * 1.15,
          wellH,
        );
        TrayComponent.paintWell(
          canvas,
          r,
          diameter: d,
          capacity: cap,
          aux: false,
          style: t.board,
        );
        final base = r.bottom - d * 0.16 - DiscArt.thickness(d);
        for (var j = 0; j < 3 + i % 2; j++) {
          DiscArt.paint(
            canvas,
            Offset(r.center.dx, base - j * DiscArt.thickness(d) - d * 0.28),
            d,
            family: CoinFamilies.all[(i + j ~/ 2) % 8],
            tier: 1,
            theme: t,
          );
        }
      }
    }
    final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('build/board_preview.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
