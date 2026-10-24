import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../domain/rules/level_validator.dart';
import 'level_pack_codec.dart';

final class LoadedPack {
  const LoadedPack(this.pack, this.rejectedIds);

  final LevelPack pack;

  /// Levels that failed validation on device and were withheld from play.
  final List<String> rejectedIds;
}

/// Loads the bundled campaign and re-validates every level before exposing
/// it (cheap: structural checks plus proof replay, no search).
final class LevelRepository {
  const LevelRepository({this.assetPath = 'assets/levels/campaign.json'});

  final String assetPath;

  Future<LoadedPack> load(AssetBundle bundle) async {
    final text = await bundle.loadString(assetPath, cache: false);
    // Decoding and replaying every proof of a 300-level pack takes long
    // enough to drop frames: do it off the UI isolate.
    if (kIsWeb) return parse(text);
    return Isolate.run(() => parse(text), debugName: 'levels');
  }

  static LoadedPack parse(String text) {
    final pack = LevelPackCodec.decode((jsonDecode(text) as Map).cast());
    const validator = LevelValidator();
    final ok = [
      for (final l in pack.levels)
        if (validator.validate(l).isEmpty) l,
    ];
    final rejected = [
      for (final l in pack.levels)
        if (!ok.contains(l)) l.id,
    ];
    if (ok.isEmpty) throw const FormatException('No valid levels in pack');
    return LoadedPack(
      LevelPack(packVersion: pack.packVersion, levels: ok),
      rejected,
    );
  }
}
