import 'dart:isolate';

import '../../domain/model/board.dart';
import '../../domain/model/objective.dart';
import '../../domain/solver/solver.dart';

/// Runs the solver off the UI isolate so hints and dead-end checks never
/// drop frames.
abstract interface class SolverRunner {
  /// [isStale] is checked right before the search starts; a stale request
  /// is skipped and reports [SolveStatus.unknownBudgetExceeded].
  Future<SolveResult> solve(
    BoardState board,
    ObjectiveDefinition objective, {
    required int maxNodes,
    bool Function()? isStale,
  });
}

/// Runs searches one at a time, in request order, skipping any that went
/// stale while queued.
///
/// Every `Isolate.run` joins the UI isolate's group, and the VM caps how
/// many of a group's isolates may run at once. Unbounded concurrent searches
/// (one dead-end check per move, plus hints) used up those slots and parked
/// the UI thread in `IsolateGroup::IncreaseMutatorCount` until they
/// finished: a multi-second freeze and an ANR. One search at a time can
/// never starve the UI.
final class SerialSolverRunner implements SolverRunner {
  SerialSolverRunner(this._inner);

  final SolverRunner _inner;
  Future<void> _tail = Future.value();

  static const _skipped = SolveResult(SolveStatus.unknownBudgetExceeded);

  @override
  Future<SolveResult> solve(
    BoardState board,
    ObjectiveDefinition objective, {
    required int maxNodes,
    bool Function()? isStale,
  }) {
    final run = _tail.then<SolveResult>((_) {
      if (isStale?.call() ?? false) return _skipped;
      return _inner.solve(board, objective, maxNodes: maxNodes);
    });
    _tail = run.then((_) {}, onError: (Object _) {});
    return run;
  }
}

final class IsolateSolverRunner implements SolverRunner {
  const IsolateSolverRunner();

  @override
  Future<SolveResult> solve(
    BoardState board,
    ObjectiveDefinition objective, {
    required int maxNodes,
    bool Function()? isStale,
  }) => Isolate.run(
    () => const Solver().solve(board, objective, maxNodes: maxNodes),
    debugName: 'solver',
  );
}

/// Same-isolate runner for tests.
final class InlineSolverRunner implements SolverRunner {
  const InlineSolverRunner();

  @override
  Future<SolveResult> solve(
    BoardState board,
    ObjectiveDefinition objective, {
    required int maxNodes,
    bool Function()? isStale,
  }) async => const Solver().solve(board, objective, maxNodes: maxNodes);
}
