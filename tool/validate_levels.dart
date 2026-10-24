// CI gate: every bundled level must pass schema checks, its stored solution
// proof must replay to a win, and an independent solver run must agree.
//
//   dart run tool/validate_levels.dart [path/to/pack.json]
import 'dart:convert';
import 'dart:io';

import 'package:coin/data/levels/level_pack_codec.dart';
import 'package:coin/domain/rules/level_validator.dart';
import 'package:coin/domain/rules/rules_engine.dart';
import 'package:coin/domain/solver/solver.dart';

void main(List<String> args) {
  final path = args.isEmpty ? 'assets/levels/campaign.json' : args.first;
  final pack = LevelPackCodec.decode(
    (jsonDecode(File(path).readAsStringSync()) as Map).cast(),
  );
  const validator = LevelValidator();
  const engine = RulesEngine();
  const solver = Solver();
  var failures = 0;
  for (final level in pack.levels) {
    final issues = validator.validate(level);
    final fresh = solver.solve(
      engine.settle(level.initialState),
      level.objective,
      maxNodes: 400000,
    );
    if (!fresh.isSolved) issues.add('independent solve: ${fresh.status.name}');
    if (issues.isEmpty) {
      stdout.writeln('ok    ${level.id}  par ${level.parMoves}');
    } else {
      failures++;
      stdout.writeln('FAIL  ${level.id}  $issues');
    }
  }
  final structural = LevelPackCodec.packIssues(pack);
  for (final i in structural) {
    failures++;
    stdout.writeln('FAIL  pack  $i');
  }
  stdout.writeln(
    failures == 0
        ? 'All ${pack.levels.length} levels verified.'
        : '$failures problem(s).',
  );
  exitCode = failures == 0 ? 0 : 1;
}
