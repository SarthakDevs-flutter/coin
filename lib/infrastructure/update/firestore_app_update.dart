import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/ports/ports.dart';

/// Version gate published in Firestore at `app_config/{android|ios}`:
///
/// ```
/// min_build:    int     builds below this must update (blocking)
/// latest_build: int     builds below this are offered an update
/// store_url:    string  fallback store page
/// message:      string? optional note shown in the prompt
/// ```
///
/// On Android the update itself runs through Play In-App Updates (no store
/// trip); elsewhere, or when Play declines, the store page opens.
final class FirestoreAppUpdate implements AppUpdatePort {
  FirestoreAppUpdate({
    required this.build,
    required this.platform,
    FirebaseFirestore? db,
  }) : _db = db ?? FirebaseFirestore.instance;

  static const collection = 'app_config';

  final int build;

  /// `android` or `ios`; the document id.
  final String platform;
  final FirebaseFirestore _db;
  String? _storeUrl;

  @override
  Future<UpdateInfo> check() async {
    try {
      final doc = await _db
          .collection(collection)
          .doc(platform)
          .get()
          .timeout(const Duration(seconds: 8));
      final d = doc.data();
      if (d == null) return UpdateInfo.none;
      _storeUrl = d['store_url'] as String?;
      return evaluate(
        build: build,
        minBuild: (d['min_build'] as num?)?.toInt() ?? 0,
        latestBuild: (d['latest_build'] as num?)?.toInt() ?? 0,
        message: d['message'] as String?,
      );
    } on Object catch (e) {
      debugPrint('update check: $e');
      return UpdateInfo.none;
    }
  }

  static UpdateInfo evaluate({
    required int build,
    required int minBuild,
    required int latestBuild,
    String? message,
  }) {
    final latest = latestBuild < minBuild ? minBuild : latestBuild;
    final urgency = build < minBuild
        ? UpdateUrgency.required
        : build < latest
        ? UpdateUrgency.optional
        : UpdateUrgency.none;
    return UpdateInfo(urgency: urgency, latestBuild: latest, message: message);
  }

  @override
  Future<void> startUpdate(UpdateInfo info) async {
    if (platform == 'android' && await _playUpdate(info)) return;
    final url = _storeUrl;
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  /// Only works for Play-installed builds; false means "use the store page".
  Future<bool> _playUpdate(UpdateInfo info) async {
    try {
      final play = await InAppUpdate.checkForUpdate();
      if (play.updateAvailability != UpdateAvailability.updateAvailable) {
        return false;
      }
      if (info.urgency == UpdateUrgency.required &&
          play.immediateUpdateAllowed) {
        return await InAppUpdate.performImmediateUpdate() ==
            AppUpdateResult.success;
      }
      if (play.flexibleUpdateAllowed) {
        final r = await InAppUpdate.startFlexibleUpdate();
        if (r != AppUpdateResult.success) return false;
        await InAppUpdate.completeFlexibleUpdate();
        return true;
      }
      return false;
    } on Object catch (e) {
      debugPrint('play update: $e');
      return false;
    }
  }
}
