import 'dart:math' as math;
import 'dart:ui';

import 'render/disc_art.dart';

/// Geometry of one board stack for layout.
final class StackSlotSpec {
  const StackSlotSpec({required this.capacity, this.workshopSlot});

  final int capacity;

  /// Position in the top workshop row, or null for a main-board tray.
  final int? workshopSlot;
}

/// Maps (stack, slot) to screen positions for disc stacks inside [area].
/// Main trays fill the fewest rows that keep coins comfortably large; an
/// optional workshop row of fixed width sits on top.
final class BoardLayout {
  BoardLayout._({
    required this.diameter,
    required this.trayRects,
    required this.hitRects,
    required this.workshopRects,
  });

  static const double trayWidthFactor = 1.34;
  static const double gapFactor = 0.24;
  static const double maxDiameter = 104;
  static const double minDiameter = 28;
  static const double comfortableDiameter = 56;

  /// Board margin around the trays (wood + gold inlay), per diameter.
  static const double frameFactor = 0.3;

  final double diameter;

  /// Aligned with the board's stacks.
  final List<Rect> trayRects;

  /// Generous tap areas (tray + lift space + half gaps), aligned with stacks.
  final List<Rect> hitRects;

  /// Every workshop row position (locked or not), left to right.
  final List<Rect> workshopRects;

  double get faceHeight => DiscArt.faceHeight(diameter);
  double get thickness => DiscArt.thickness(diameter);

  /// How far a selected run rises.
  double get lift => faceHeight * 0.62;

  static double _pad(double d) => d * 0.16;

  static double trayHeight(double d, int capacity) =>
      DiscArt.faceHeight(d) +
      DiscArt.thickness(d) * (capacity + 1) +
      _pad(d) * 2;

  static double _rowHeight(double d, int cap) =>
      trayHeight(d, cap) + DiscArt.faceHeight(d) * 0.9;

  factory BoardLayout.compute(
    Rect area,
    List<StackSlotSpec> stacks, {
    int workshopRow = 0,
    int workshopCapacity = 6,
  }) {
    final main = [
      for (var i = 0; i < stacks.length; i++)
        if (stacks[i].workshopSlot == null) i,
    ];
    final n = main.length;
    final cap = main.fold<int>(1, (m, i) => math.max(m, stacks[i].capacity));
    final hasRow = workshopRow > 0;
    final rowUnit = hasRow ? _rowHeight(1, workshopCapacity) + gapFactor : 0.0;
    final rowWidthUnit = hasRow
        ? workshopRow * trayWidthFactor + (workshopRow - 1) * gapFactor
        : 0.0;
    var best = minDiameter;
    var bestRows = 1;
    for (var rows = 1; rows <= 3; rows++) {
      final cols = (n / rows).ceil();
      if (rows > 1 && cols < 2) break;
      final widthUnit = math.max(
        cols * trayWidthFactor + (cols - 1) * gapFactor,
        rowWidthUnit,
      );
      final dW = area.width / (widthUnit + frameFactor * 2);
      final unit = _rowHeight(1, cap);
      final dH =
          area.height /
          (rows * unit + (rows - 1) * gapFactor + rowUnit + frameFactor * 2);
      final d = math.min(math.min(dW, dH), maxDiameter);
      if (d >= comfortableDiameter) {
        best = d;
        bestRows = rows;
        break;
      }
      if (d > best + 0.5) {
        best = d;
        bestRows = rows;
      }
    }
    final d = best.clamp(minDiameter, maxDiameter).toDouble();
    final rows = bestRows;
    final cols = math.max(1, (n / rows).ceil());
    final trayW = d * trayWidthFactor;
    final gap = d * gapFactor;
    final rowH = _rowHeight(d, cap);
    final topRowH = hasRow ? _rowHeight(d, workshopCapacity) + gap : 0.0;
    final totalH = topRowH + rows * rowH + (rows - 1) * gap;
    final top = area.top + (area.height - totalH) / 2;

    final trays = List<Rect>.filled(stacks.length, Rect.zero);
    final hits = List<Rect>.filled(stacks.length, Rect.zero);
    final workshop = <Rect>[];
    if (hasRow) {
      final rowW = workshopRow * trayW + (workshopRow - 1) * gap;
      final left = area.left + (area.width - rowW) / 2;
      final bottom = top + topRowH - gap;
      final h = trayHeight(d, workshopCapacity);
      for (var c = 0; c < workshopRow; c++) {
        final x = left + c * (trayW + gap);
        workshop.add(Rect.fromLTWH(x, bottom - h, trayW, h));
      }
      for (var i = 0; i < stacks.length; i++) {
        final w = stacks[i].workshopSlot;
        if (w == null || w >= workshop.length) continue;
        final r = workshop[w];
        trays[i] = r;
        hits[i] = Rect.fromLTRB(
          r.left - gap / 2,
          top - gap / 2,
          r.right + gap / 2,
          r.bottom + gap / 2,
        );
      }
    }
    var index = 0;
    for (var r = 0; r < rows; r++) {
      final inRow = math.min(cols, n - index);
      if (inRow <= 0) break;
      final rowW = inRow * trayW + (inRow - 1) * gap;
      final left = area.left + (area.width - rowW) / 2;
      final rowTop = top + topRowH + r * (rowH + gap);
      final bottom = rowTop + rowH;
      for (var c = 0; c < inRow; c++) {
        final si = main[index];
        final x = left + c * (trayW + gap);
        final h = trayHeight(d, stacks[si].capacity);
        trays[si] = Rect.fromLTWH(x, bottom - h, trayW, h);
        hits[si] = Rect.fromLTRB(
          x - gap / 2,
          rowTop - gap / 2,
          x + trayW + gap / 2,
          bottom + gap / 2,
        );
        index++;
      }
    }
    return BoardLayout._(
      diameter: d,
      trayRects: trays,
      hitRects: hits,
      workshopRects: workshop,
    );
  }

  /// Outer edge of the wooden board holding every tray position.
  Rect get frameRect {
    final all = [...trayRects.where((r) => r != Rect.zero), ...workshopRects];
    if (all.isEmpty) return Rect.zero;
    final u = all.reduce((a, b) => a.expandToInclude(b));
    final m = diameter * frameFactor;
    return Rect.fromLTRB(u.left - m, u.top - m, u.right + m, u.bottom + m);
  }

  /// Face centre of the coin at [slot] (0 = bottom) in tray [stack].
  Offset slot(int stack, int slot) {
    final r = trayRects[stack];
    final base = r.bottom - _pad(diameter);
    return Offset(
      r.center.dx,
      base - faceHeight / 2 - thickness - slot * thickness,
    );
  }
}
