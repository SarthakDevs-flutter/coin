// CI gate: every asset in assets/ASSET_MANIFEST.json exists and has a
// license, and every file under assets/ is listed in the manifest.
//
//   dart run tool/check_assets.dart
import 'dart:convert';
import 'dart:io';

void main() {
  final manifest =
      (jsonDecode(File('assets/ASSET_MANIFEST.json').readAsStringSync())
              as Map)['assets']
          as List;
  final listed = <String>{};
  var problems = 0;
  for (final raw in manifest) {
    final e = (raw as Map).cast<String, Object?>();
    final path = e['path']! as String;
    listed.add(path);
    if (!File(path).existsSync()) {
      stdout.writeln('MISSING  $path');
      problems++;
    }
    if ((e['license'] as String?)?.isEmpty ?? true) {
      stdout.writeln('NO LICENSE  $path');
      problems++;
    }
  }
  const ignored = {
    'assets/ASSET_MANIFEST.json',
    'assets/fonts/Fredoka-OFL.txt',
    'assets/fonts/Nunito-OFL.txt',
  };
  for (final f in Directory(
    'assets',
  ).listSync(recursive: true).whereType<File>()) {
    final p = f.path.replaceAll(r'\', '/');
    if (ignored.contains(p) || p.endsWith('.DS_Store')) continue;
    if (!listed.contains(p)) {
      stdout.writeln('UNLISTED  $p');
      problems++;
    }
  }
  stdout.writeln(
    problems == 0
        ? 'Assets OK (${listed.length}).'
        : '$problems asset problem(s).',
  );
  exitCode = problems == 0 ? 0 : 1;
}
