import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../application/ports/ports.dart';

/// Files in the app-support directory. Writes go to a temp file that is
/// flushed and then renamed over the target, which is atomic on the same
/// filesystem on Android and iOS.
final class FileSaveStore implements SaveStore {
  FileSaveStore([Directory? dir]) : _dir = dir;

  Directory? _dir;

  Future<Directory> _root() async {
    final d = _dir ??= Directory(
      '${(await getApplicationSupportDirectory()).path}/saves',
    );
    if (!d.existsSync()) await d.create(recursive: true);
    return d;
  }

  @override
  Future<String?> read(String name) async {
    final f = File('${(await _root()).path}/$name');
    if (!f.existsSync()) return null;
    return f.readAsString();
  }

  @override
  Future<void> write(String name, String contents) async {
    final root = await _root();
    final tmp = File('${root.path}/$name.tmp');
    await tmp.writeAsString(contents, flush: true);
    await tmp.rename('${root.path}/$name');
  }

  @override
  Future<void> delete(String name) async {
    final f = File('${(await _root()).path}/$name');
    if (f.existsSync()) await f.delete();
  }
}

/// In-memory store for tests and as a last-resort fallback when the
/// filesystem is unavailable.
final class MemorySaveStore implements SaveStore {
  final Map<String, String> files = {};
  bool failWrites = false;

  @override
  Future<String?> read(String name) async => files[name];

  @override
  Future<void> write(String name, String contents) async {
    if (failWrites) throw const FileSystemException('simulated failure');
    files[name] = contents;
  }

  @override
  Future<void> delete(String name) async => files.remove(name);
}
