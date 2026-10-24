import 'package:coin/application/session/solver_runner.dart';
import 'package:coin/domain/model/board.dart';
import 'package:coin/domain/model/objective.dart';
import 'package:coin/domain/solver/solver.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/test_boards.dart';

/// Inner runner that records how many searches overlap.
final class _Probe implements SolverRunner {
  int running = 0;
  int maxRunning = 0;
  int calls = 0;

  @override
  Future<SolveResult> solve(
    BoardState board,
    ObjectiveDefinition objective, {
    required int maxNodes,
    bool Function()? isStale,
  }) async {
    calls++;
    running++;
    if (running > maxRunning) maxRunning = running;
    await Future<void>.delayed(const Duration(milliseconds: 5));
    running--;
    return const SolveResult(SolveStatus.unsolvedProven);
  }
}

void main() {
  final b = board(['J J', '']);
  const objective = ClearBoardObjective();

  test('serial runner never overlaps searches', () async {
    final probe = _Probe();
    final runner = SerialSolverRunner(probe);
    await Future.wait([
      for (var i = 0; i < 8; i++) runner.solve(b, objective, maxNodes: 10),
    ]);
    expect(probe.calls, 8);
    expect(probe.maxRunning, 1);
  });

  test('stale requests are skipped before they start', () async {
    final probe = _Probe();
    final runner = SerialSolverRunner(probe);
    var revision = 0;
    final results = <Future<SolveResult>>[];
    for (var i = 0; i < 5; i++) {
      revision++;
      final mine = revision;
      results.add(
        runner.solve(
          b,
          objective,
          maxNodes: 10,
          isStale: () => mine != revision,
        ),
      );
    }
    final out = await Future.wait(results);
    // Only the newest request runs.
    expect(probe.calls, 1);
    expect(out.last.status, SolveStatus.unsolvedProven);
    expect(
      out.take(4).every((r) => r.status == SolveStatus.unknownBudgetExceeded),
      isTrue,
    );
  });

  test('a failing search does not block the queue', () async {
    final runner = SerialSolverRunner(_Failing());
    await expectLater(
      runner.solve(b, objective, maxNodes: 1),
      throwsStateError,
    );
    final probe = _Probe();
    final next = SerialSolverRunner(probe);
    await next.solve(b, objective, maxNodes: 1);
    expect(probe.calls, 1);
  });
}

final class _Failing implements SolverRunner {
  @override
  Future<SolveResult> solve(
    BoardState board,
    ObjectiveDefinition objective, {
    required int maxNodes,
    bool Function()? isStale,
  }) async => throw StateError('boom');
}
