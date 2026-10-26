import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Starts Firebase once. Returns false (and the app falls back to local
/// adapters) when the project isn't configured or the platform has no
/// Firebase support.
abstract final class FirebaseBootstrap {
  static Future<bool> start() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      return true;
    } on Object catch (e) {
      debugPrint('firebase: not started ($e)');
      return false;
    }
  }
}
