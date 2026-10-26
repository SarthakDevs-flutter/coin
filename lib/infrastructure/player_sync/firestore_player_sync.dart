import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../application/ports/ports.dart';

/// Mirrors [PlayerSnapshot] to `players/{uid}` in Firestore.
///
/// The id is a Firebase anonymous-auth uid: pseudonymous, per install,
/// reset on reinstall, and the key the security rules check (a player can
/// only touch their own document). Upgrading to a linked account later
/// keeps the same uid.
final class FirestorePlayerSync implements PlayerSyncPort {
  FirestorePlayerSync({FirebaseAuth? auth, FirebaseFirestore? db})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = db ?? FirebaseFirestore.instance;

  static const collection = 'players';

  /// Bump when the document shape changes; backend jobs read it.
  static const schemaVersion = 1;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  Future<String?>? _signIn;

  @override
  Future<String?> playerId() {
    final current = _auth.currentUser;
    if (current != null) return Future.value(current.uid);
    return _signIn ??= _auth
        .signInAnonymously()
        .then<String?>((c) => c.user?.uid)
        .catchError((Object e) {
          debugPrint('player sync: sign-in failed ($e)');
          _signIn = null; // retry on the next call
          return null;
        });
  }

  @override
  Future<void> push(PlayerSnapshot s) async {
    final uid = await playerId();
    if (uid == null) return;
    // No await on the write: Firestore applies it to the local cache at
    // once and retries the server write itself, offline included.
    _db
        .collection(collection)
        .doc(uid)
        .set({
          'schema': schemaVersion,
          'platform': s.platform,
          'app_version': s.appVersion,
          'build': s.build,
          'country': s.country,
          'locale': s.locale,
          'highest_level': s.highestLevel,
          'levels_completed': s.levelsCompleted,
          'tutorial_done': s.tutorialDone,
          'remove_ads': s.removeAds,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true))
        .catchError((Object e) => debugPrint('player sync: write failed ($e)'));
  }

  @override
  Future<void> erase() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection(collection).doc(uid).delete();
    } on Object catch (e) {
      debugPrint('player sync: erase failed ($e)');
    }
  }
}
