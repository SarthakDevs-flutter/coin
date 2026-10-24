import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../model/board.dart';
import '../model/move.dart';
import '../model/objective.dart';
import '../rules/rules_engine.dart';

enum SolveStatus {
  /// [SolveResult.path] reaches the objective.
  solved,

  /// The whole reachable state space was searched: no solution exists.
  unsolvedProven,

  /// Search stopped at its budget. This is NOT evidence of impossibility.
  unknownBudgetExceeded,

  /// The board violates structural invariants.
  invalidLevel,
}

final class SolveResult {
  const SolveResult(
    this.status, {
    this.path = const [],
    this.nodesExpanded = 0,
  });

  final SolveStatus status;
  final List<MoveCommand> path;
  final int nodesExpanded;

  bool get isSolved => status == SolveStatus.solved;
}

/// Bounded best-first search over the canonical [RulesEngine]. Correctness
/// over speed: pruning only removes moves that lead to states symmetric to
/// ones already generated.
final class Solver {
  const Solver({this.engine = const RulesEngine()});

  static const int version = 4;

  final RulesEngine engine;

  SolveResult solve(
    BoardState start,
    ObjectiveDefinition objective, {
    int maxNodes = 200000,
  }) {
    if (engine.invariantViolations(start).isNotEmpty) {
      return const SolveResult(SolveStatus.invalidLevel);
    }
    if (objective.isMet(start)) {
      return const SolveResult(SolveStatus.solved);
    }
    // Tray identity matters when frost (adjacency) or deals (targets) exist.
    final symmetric = !_hasFrost(start) && start.deals.isEmpty;
    final seen = <String>{_key(start, objective, symmetric)};
    final heap = _Heap();
    final nodes = <_Node>[_Node(start, null, null, 0)];
    heap.push(_priority(start, 0), 0);
    var expanded = 0;

    while (heap.isNotEmpty) {
      if (expanded >= maxNodes) {
        return SolveResult(
          SolveStatus.unknownBudgetExceeded,
          nodesExpanded: expanded,
        );
      }
      final idx = heap.pop();
      final node = nodes[idx];
      expanded++;
      for (final move in _candidateMoves(node.state, symmetric)) {
        final next = engine.apply(node.state, move, recordEvents: false).next;
        final key = _key(next, objective, symmetric);
        if (!seen.add(key)) continue;
        final child = _Node(next, idx, move, node.depth + 1);
        nodes.add(child);
        if (objective.isMet(next)) {
          return SolveResult(
            SolveStatus.solved,
            path: _path(nodes, nodes.length - 1),
            nodesExpanded: expanded,
          );
        }
        heap.push(_priority(next, child.depth), nodes.length - 1);
      }
    }
    return SolveResult(SolveStatus.unsolvedProven, nodesExpanded: expanded);
  }

  /// Replays [path] from [start] and checks every move is legal and the
  /// objective is met at the end. Used to verify stored solution proofs.
  bool verifyPath(
    BoardState start,
    ObjectiveDefinition objective,
    List<MoveCommand> path,
  ) {
    var s = start;
    for (final m in path) {
      if (!engine.isLegal(s, m)) return false;
      s = engine.apply(s, m, recordEvents: false).next;
    }
    return objective.isMet(s);
  }

  static String hashPath(List<MoveCommand> path) => sha256
      .convert(utf8.encode(path.map((m) => '${m.from}>${m.to}').join(',')))
      .toString();

  Iterable<MoveCommand> _candidateMoves(BoardState s, bool symmetric) sync* {
    if (engine.validateDeal(s).isLegal) yield MoveCommand.deal;
    final usedEmptyCaps = <int>{};
    for (final dst in s.stacks) {
      if (dst.isEmpty && symmetric) {
        // Empty trays of equal capacity are interchangeable.
        if (!usedEmptyCaps.add(dst.capacity)) continue;
      }
      for (final src in s.stacks) {
        if (identical(src, dst) || src.isEmpty) continue;
        if (symmetric &&
            dst.isEmpty &&
            src.topRunLength == src.coins.length &&
            src.capacity == dst.capacity) {
          continue; // moving a whole uniform stack into an equal empty tray
        }
        final m = MoveCommand(src.id, dst.id);
        if (engine.isLegal(s, m)) yield m;
      }
    }
  }

  static bool _hasFrost(BoardState s) =>
      s.stacks.any((st) => st.coins.any((c) => c.isFrozen));

  static String _key(
    BoardState s,
    ObjectiveDefinition objective,
    bool symmetric,
  ) {
    final parts = <String>[];
    for (final st in s.stacks) {
      final b = StringBuffer()
        ..write(st.capacity)
        ..write(':');
      for (final c in st.coins) {
        b
          ..write(c.familyId)
          ..write(c.tier);
        if (c.frost > 0) b.write('*${c.frost}');
        if (!c.isRevealed) b.write('?');
        b.write(',');
      }
      parts.add(b.toString());
    }
    if (symmetric) parts.sort();
    final dealt = s.deals.isEmpty ? '' : '~${s.dealIndex}';
    final extra =
        dealt +
        switch (objective) {
          ForgeObjective(:final tier, :final count) =>
            '#${s.progress.forgedOfTier(tier).clamp(0, count)}',
          ClearBoardObjective() => '',
        };
    return parts.join('|') + extra;
  }

  /// Lower is better: unsorted boundaries dominate, depth breaks ties.
  ///
  /// Coins still waiting in deals count as on the board and unsorted, so
  /// dealing is neutral. Otherwise every deal looks like a step backwards
  /// and the search exhausts all re-arrangements of the board before
  /// dealing, which explodes on big boards.
  ///
  /// The unsorted measure is the number of separate runs beyond one per
  /// kind: a kind split across two trays still has to be gathered even when
  /// each tray is uniform (what fill mode needs; it helps classic boards
  /// too).
  static int _priority(BoardState s, int depth) {
    var runs = 0;
    var coins = 0;
    var frozen = 0;
    final kinds = <String>{};
    for (var i = s.dealIndex; i < s.deals.length; i++) {
      final n = s.deals[i].coinCount;
      coins += n;
      runs += n;
    }
    for (final st in s.stacks) {
      coins += st.coins.length;
      for (var i = 0; i < st.coins.length; i++) {
        final c = st.coins[i];
        kinds.add('${c.familyId}${c.tier}');
        if (i == 0 || !c.sameKindAs(st.coins[i - 1])) runs++;
        if (c.isFrozen) frozen++;
      }
    }
    return (runs - kinds.length) * 6 + frozen * 6 + coins * 2 + depth;
  }

  static List<MoveCommand> _path(List<_Node> nodes, int idx) {
    final out = <MoveCommand>[];
    var i = idx;
    while (nodes[i].parent != null) {
      out.add(nodes[i].move!);
      i = nodes[i].parent!;
    }
    return out.reversed.toList(growable: false);
  }
}

final class _Node {
  _Node(this.state, this.parent, this.move, this.depth);
  final BoardState state;
  final int? parent;
  final MoveCommand? move;
  final int depth;
}

/// Minimal binary min-heap of (priority, nodeIndex); FIFO on ties for
/// deterministic results.
final class _Heap {
  final _p = <int>[];
  final _v = <int>[];
  final _seq = <int>[];
  var _counter = 0;

  bool get isNotEmpty => _p.isNotEmpty;

  void push(int priority, int value) {
    _p.add(priority);
    _v.add(value);
    _seq.add(_counter++);
    var i = _p.length - 1;
    while (i > 0) {
      final parent = (i - 1) >> 1;
      if (!_less(i, parent)) break;
      _swap(i, parent);
      i = parent;
    }
  }

  int pop() {
    final result = _v[0];
    final last = _p.length - 1;
    _swap(0, last);
    _p.removeLast();
    _v.removeLast();
    _seq.removeLast();
    var i = 0;
    while (true) {
      final l = i * 2 + 1;
      final r = l + 1;
      var m = i;
      if (l < _p.length && _less(l, m)) m = l;
      if (r < _p.length && _less(r, m)) m = r;
      if (m == i) break;
      _swap(i, m);
      i = m;
    }
    return result;
  }

  bool _less(int a, int b) =>
      _p[a] < _p[b] || (_p[a] == _p[b] && _seq[a] < _seq[b]);

  void _swap(int a, int b) {
    final p = _p[a], v = _v[a], s = _seq[a];
    _p[a] = _p[b];
    _v[a] = _v[b];
    _seq[a] = _seq[b];
    _p[b] = p;
    _v[b] = v;
    _seq[b] = s;
  }
}
