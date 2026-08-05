import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'services/preferences_service.dart';
import 'services/vault_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // media_kit native libraries (libmpv) must be initialised before any
  // Player instance is created. Guarded: if the native libs fail to load
  // on this device, the app must still open (playback will surface the
  // error later instead of crashing on launch).
  try {
    MediaKit.ensureInitialized();
  } catch (e, st) {
    debugPrint('MediaKit init failed: $e\n$st');
  }

  // Edge-to-edge rendering with transparent system bars (Fire OS friendly).
  try {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  } catch (_) {}
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final prefs = await PreferencesService.init();
  final vaultService = VaultService(prefs);

  runApp(LuvioPlayerApp(prefs: prefs, vaultService: vaultService));
}
