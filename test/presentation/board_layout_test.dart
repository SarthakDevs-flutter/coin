import 'dart:ui';

import 'package:coin/game/board_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tray counts per row, top to bottom.
List<int> _rows(BoardLayout l) {
  final byTop = <double, int>{};
  for (final r in l.trayRects) {
    byTop[r.bottom] = (byTop[r.bottom] ?? 0) + 1;
  }
  final keys = byTop.keys.toList()..sort();
  return [for (final k in keys) byTop[k]!];
}

BoardLayout _layout(int n, int cap, Size area, {int workshop = 5}) =>
    BoardLayout.compute(
      Offset.zero & area,
      [for (var i = 0; i < n; i++) StackSlotSpec(capacity: cap)],
      workshopRow: workshop,
      workshopCapacity: cap,
    );

void main() {
  const phone = Size(395, 520);

  test('late boards stay inside the area with evenly filled rows', () {
    for (final (n, cap) in [(13, 10), (16, 10), (16, 11), (16, 12)]) {
      final l = _layout(n, cap, phone);
      final frame = l.frameRect;
      expect(frame.left, greaterThanOrEqualTo(-0.5), reason: '$n/$cap');
      expect(frame.top, greaterThanOrEqualTo(-0.5), reason: '$n/$cap');
      expect(frame.right, lessThanOrEqualTo(phone.width + 0.5));
      expect(frame.bottom, lessThanOrEqualTo(phone.height + 0.5));
      final rows = _rows(l);
      expect(rows.reduce((a, b) => a + b), n);
      final spread =
          rows.reduce((a, b) => a > b ? a : b) -
          rows.reduce((a, b) => a < b ? a : b);
      expect(spread, lessThanOrEqualTo(1), reason: '$n/$cap rows $rows');
      expect(l.diameter, greaterThanOrEqualTo(36), reason: '$n/$cap');
    }
  });

  test('locked workshop row only takes the height of its cards', () {
    final l = _layout(16, 12, phone);
    final card = l.workshopRects.first;
    expect(
      card.height,
      closeTo(l.diameter * BoardLayout.lockedCardFactor, 0.01),
    );

    // Once a slot is unlocked it becomes a full tray.
    final open = BoardLayout.compute(
      Offset.zero & phone,
      [
        for (var i = 0; i < 16; i++) const StackSlotSpec(capacity: 12),
        const StackSlotSpec(capacity: 12, workshopSlot: 0),
      ],
      workshopRow: 5,
      workshopCapacity: 12,
    );
    expect(
      open.workshopRects.first.height,
      closeTo(BoardLayout.trayHeight(open.diameter, 12), 0.01),
    );
  });

  test('early boards keep the fewest rows that are comfortable', () {
    // Roomy area: one row is comfortable, so no extra rows are added.
    final roomy = _layout(4, 3, const Size(395, 700), workshop: 0);
    expect(_rows(roomy), [4]);
    expect(
      roomy.diameter,
      greaterThanOrEqualTo(BoardLayout.comfortableDiameter),
    );
    expect(_rows(_layout(7, 4, phone)), [4, 3]);
  });

  test('crowded boards never spill off screen', () {
    // Level 281+: many tall trays used to fall back to one overflowing row.
    for (final h in [380.0, 420.0, 520.0]) {
      for (final n in [14, 16, 18, 20]) {
        for (final cap in [10, 12, 14, 16]) {
          final area = Size(356, h);
          final l = _layout(n, cap, area);
          final frame = l.frameRect;
          final why = 'h$h n$n cap$cap';
          expect(frame.left, greaterThanOrEqualTo(-0.5), reason: why);
          expect(frame.top, greaterThanOrEqualTo(-0.5), reason: why);
          expect(frame.right, lessThanOrEqualTo(area.width + 0.5), reason: why);
          expect(frame.bottom, lessThanOrEqualTo(h + 0.5), reason: why);
          expect(_rows(l).length, greaterThan(1), reason: why);
        }
      }
    }
  });
}
