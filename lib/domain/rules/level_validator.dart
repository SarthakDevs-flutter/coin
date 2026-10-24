import '../model/board.dart';
import '../model/families.dart';
import '../model/level.dart';
import '../model/objective.dart';
import '../solver/solver.dart';
import 'rules_engine.dart';

/// Schema and fairness checks for a level. Standard campaign levels must pass
/// with zero issues before they can be played (features-and-flows.md §5.5).
final class LevelValidator {
  const LevelValidator({this.engine = const RulesEngine()});

  final RulesEngine engine;

  List<String> structuralIssues(LevelDefinition level) {
    final issues = <String>[];
    final board = engine.settle(level.initialState);
    final rules = board.rules;
    if (rules.mergeThreshold < 2) issues.add('mergeThreshold < 2');
    if (rules.maxTier < 1) issues.add('maxTier < 1');
    if (board.stacks.length < 2) issues.add('fewer than 2 stacks');
    if (!board.stacks.any((s) => s.capacity >= rules.mergeThreshold)) {
      issues.add('no stack can hold a full set');
    }
    if (board.moveCount != 0) issues.add('initial moveCount != 0');
    if (board.progress != ObjectiveProgress.empty) {
      issues.add('initial progress not empty');
    }
    final allCoins = [
      for (final s in board.stacks) ...s.coins,
      for (final d in board.deals) ...d.coins,
    ];
    for (final d in board.deals) {
      if (d.drops.isEmpty) issues.add('empty deal batch');
    }
    for (final c in allCoins) {
      if (!CoinFamilies.isKnown(c.familyId)) {
        issues.add('unknown family ${c.familyId}');
      }
      if (c.id.startsWith('f')) issues.add('reserved coin id ${c.id}');
    }
    issues.addAll(engine.invariantViolations(board));

    switch (level.objective) {
      case ClearBoardObjective():
        // In fill mode set sizes follow the trays; the solver proof is the
        // only guarantee that every family can be cleared.
        if (rules.fillToSeal) break;
        final units = <String, int>{};
        for (final c in allCoins) {
          units[c.familyId] =
              (units[c.familyId] ?? 0) + _pow(rules.mergeThreshold, c.tier - 1);
        }
        final set = _pow(rules.mergeThreshold, rules.maxTier);
        for (final e in units.entries) {
          if (e.value % set != 0) {
            issues.add('family ${e.key} cannot be fully sealed');
          }
        }
      case ForgeObjective(:final tier):
        if (tier > rules.maxTier) issues.add('forge tier above maxTier');
    }

    if (level.isTutorial) {
      var s = board;
      final history = <BoardState>[];
      for (final step in level.tutorial) {
        if (step.expectUndo) {
          if (history.isEmpty) {
            issues.add('tutorial undo step ${step.messageKey} has no move');
            break;
          }
          s = history.removeLast();
          continue;
        }
        final m = step.move;
        if (m == null) continue;
        history.add(s);
        if (!engine.isLegal(s, m)) {
          issues.add('tutorial step ${step.messageKey} is illegal');
          break;
        }
        s = engine.apply(s, m, recordEvents: false).next;
      }
    }
    return issues;
  }

  /// Full check including the stored solution proof.
  List<String> validate(
    LevelDefinition level, {
    Solver solver = const Solver(),
  }) {
    final issues = structuralIssues(level);
    if (issues.isNotEmpty) return issues;
    final proof = level.proof;
    if (proof == null) return ['missing solver proof'];
    final board = engine.settle(level.initialState);
    if (!solver.verifyPath(board, level.objective, proof.solution)) {
      issues.add('stored solution does not solve the level');
    }
    if (Solver.hashPath(proof.solution) != proof.solutionHash) {
      issues.add('solution hash mismatch');
    }
    return issues;
  }

  static int _pow(int b, int e) {
    var r = 1;
    for (var i = 0; i < e; i++) {
      r *= b;
    }
    return r;
  }
}
