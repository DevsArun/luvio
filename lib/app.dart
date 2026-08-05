import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/routes.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'providers/audio_library_provider.dart';
import 'providers/audio_player_provider.dart';
import 'providers/library_provider.dart';
import 'providers/player_provider.dart';
import 'providers/playlist_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/vault_provider.dart';
import 'services/preferences_service.dart';
import 'services/vault_service.dart';
import 'widgets/pip/pip_overlay_host.dart';

/// Root navigator key — lets the PiP overlay (which lives above the
/// navigator) push the fullscreen player route.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class LuvioPlayerApp extends StatelessWidget {
  const LuvioPlayerApp({
    super.key,
    required this.prefs,
    required this.vaultService,
  });

  final PreferencesService prefs;
  final VaultService vaultService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<VaultService>.value(value: vaultService),
        ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
        ChangeNotifierProvider(
          create: (_) => LibraryProvider(prefs, vaultService),
        ),
        ChangeNotifierProvider(create: (_) => PlaylistProvider(prefs)),
        ChangeNotifierProvider(
          create: (context) =>
              VaultProvider(vaultService, context.read<LibraryProvider>()),
        ),
        ChangeNotifierProvider(
          create: (context) => PlayerProvider(
            settings: context.read<SettingsProvider>(),
            library: context.read<LibraryProvider>(),
          ),
        ),
        ChangeNotifierProvider(create: (_) => AudioLibraryProvider(prefs)),
        ChangeNotifierProvider(
          create: (context) => AudioPlayerProvider(
            settings: context.read<SettingsProvider>(),
            library: context.read<AudioLibraryProvider>(),
          ),
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          // Resolve the active palette FIRST so every AppColors /
          // AppTypography lookup below builds with the right colors.
          AppColors.isLight = !settings.darkTheme;
          return MaterialApp(
        title: 'Luvio Player',
        debugShowCheckedModeBanner: false,
        navigatorKey: rootNavigatorKey,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode:
            settings.darkTheme ? ThemeMode.dark : ThemeMode.light,
        initialRoute: Routes.splash,
        onGenerateRoute: Routes.onGenerateRoute,
        // The PiP window floats above every route.
        builder: (context, child) => Stack(
          children: [
            if (child != null) child,
            PipOverlayHost(),
          ],
        ),
        );
        },
      ),
    );
  }
}
