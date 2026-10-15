import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'cloud/auth_service.dart';
import 'cloud/cloud_backend.dart';
import 'cloud/cloud_config.dart';
import 'firebase_options.dart'; // made by `flutterfire configure`
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  await state.load();
  await state.loadRequirements();

  // Online backend: accounts (Firebase Auth), answers (Firestore), PDFs (Google Drive).
  // The app still works offline; only Submit needs internet.
  if (CloudConfig.enabled) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      state.backend = CloudBackend();
      state.onSignOut = AuthService.logOut;
      AuthService.watchStatus(state); // shows Pending / Returned / Accepted from OLEDIPO
    } catch (e) {
      debugPrint('Firebase not started, Submit stays on this phone: $e');
    }
  }

  runApp(ChangeNotifierProvider<AppState>.value(value: state, child: const NegosyoPlanApp()));
}