// Placeholder until the Firebase project is connected. Running
// `flutterfire configure` overwrites this file with the real options; until
// then the app starts without Firebase and uses its local adapters.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
    'Firebase is not configured. Run `flutterfire configure`.',
  );
}
