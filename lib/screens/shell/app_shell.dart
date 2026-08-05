import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../providers/library_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/permission_service.dart';
import '../../widgets/shell/side_nav_bar.dart';
import '../equalizer/equalizer_screen.dart';
import '../folders/folder_browser_screen.dart';
import '../home/home_dashboard_screen.dart';
import '../playlists/playlist_manager_screen.dart';
import '../settings/settings_screen.dart';
import '../audio/audio_library_screen.dart';
import '../files/file_manager_screen.dart';
import '../vault/vault_screen.dart';

/// Primary sections reachable from the navigation rail.
enum AppSection { home, library,
  audio,
  files, folders, vault, settings, equalizer }

/// Main app scaffold: persistent 288px side rail (≥1024px width) or a
/// drawer on narrow/portrait layouts, with animated section switching.
class AppShell extends StatefulWidget {
  // MX Player opens straight on the folder list, so that is our landing tab.
  const AppShell({super.key, this.initialSection = AppSection.folders});

  final AppSection initialSection;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  late AppSection _section = widget.initialSection;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Refresh the library on launch. Without this the app only ever scanned
    // from the onboarding screen, so a video copied to the device later never
    // showed up until the user manually opened Scan Storage.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshLibrary());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the file manager / a download: pick up new files.
    if (state == AppLifecycleState.resumed) _refreshLibrary();
  }

  Future<void> _refreshLibrary() async {
    if (!mounted) return;
    final library = context.read<LibraryProvider>();
    if (library.isScanning) return;
    final granted = await PermissionService().hasMediaPermission();
    if (!granted || !mounted) return;
    await library.startScan();
  }

  void _select(AppSection section) {
    if (_section == section) return;
    setState(() => _section = section);
  }

  Widget get _content {
    return AnimatedSwitcher(
      duration: AppMotion.medium,
      switchInCurve: AppMotion.ease,
      switchOutCurve: AppMotion.ease,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, 0.01),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: ValueKey(_section),
        child: switch (_section) {
          AppSection.home =>
            HomeDashboardScreen(onSectionSelected: _select),
          AppSection.library => PlaylistManagerScreen(),
      AppSection.audio => const AudioLibraryScreen(),
      AppSection.files => const FileManagerScreen(),
          AppSection.folders => FolderBrowserScreen(),
          AppSection.vault => VaultScreen(),
          AppSection.settings =>
            SettingsScreen(onSectionSelected: _select),
          AppSection.equalizer => EqualizerScreen(),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild every section immediately when settings (theme) change.
    context.watch<SettingsProvider>();
    final wide = MediaQuery.of(context).size.width >= 1024;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            SideNavBar(section: _section, onSectionSelected: _select),
            Expanded(child: _content),
          ],
        ),
      );
    }

    // Narrow / portrait: drawer navigation.
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryContainer,
                    AppColors.accentPurple,
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 18),
            ),
            SizedBox(width: 10),
            Text('Luvio Player',
                style: AppTypography.headlineMd.copyWith(fontSize: 20)),
          ],
        ),
      ),
      drawer: Drawer(
        width: SideNavBar.width,
        backgroundColor: AppColors.surfaceContainerLowest,
        child: Builder(
          builder: (drawerContext) => SideNavBar(
            section: _section,
            onSectionSelected: (s) {
              Navigator.of(drawerContext).pop();
              _select(s);
            },
          ),
        ),
      ),
      body: _content,
    );
  }
}
