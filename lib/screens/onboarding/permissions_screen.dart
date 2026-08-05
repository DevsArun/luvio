import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../providers/library_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/permission_service.dart';

/// Permissions onboarding — a centered glass panel split into an
/// illustration side and a content side ("Access your Videos", two
/// benefit rows, Continue / Not Now pills), matching the reference.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  final _permissions = PermissionService();
  bool _requesting = false;
  bool _denied = false;

  Future<void> _allow() async {
    setState(() {
      _requesting = true;
      _denied = false;
    });
    final granted = await _permissions.requestMediaPermission();
    if (!mounted) return;
    setState(() => _requesting = false);

    if (granted) {
      // Android 13+: needed for the lockscreen / notification media controls.
      await _permissions.requestNotificationPermission();
      if (!mounted) return;
      final settings = context.read<SettingsProvider>();
      final library = context.read<LibraryProvider>();
      await settings.setOnboardingDone(true);
      library.startScan();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(Routes.shell);
    } else {
      setState(() => _denied = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Permission denied — Luvio Player can’t find your videos without it.'),
          action: SnackBarAction(
            label: 'Open Settings',
            onPressed: _permissions.openSettings,
          ),
        ),
      );
    }
  }

  Future<void> _skip() async {
    await context.read<SettingsProvider>().setOnboardingDone(true);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(Routes.shell);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: SingleChildScrollView(
          padding:
              EdgeInsets.all(AppSpacing.containerPadding),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 896),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.card.withOpacity(0.8),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: Colors.white.withOpacity(0.05)),
                boxShadow: AppColors.ambientShadow,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wide)
                      Expanded(child: _IllustrationPane()),
                    Expanded(child: _ContentPane(
                      requesting: _requesting,
                      denied: _denied,
                      onAllow: _allow,
                      onSkip: _skip,
                      onOpenSettings: _permissions.openSettings,
                    )),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Left illustration side — cinematic folder artwork recreated with
/// gradients and glowing iconography (no network assets).
class _IllustrationPane extends StatelessWidget {
  _IllustrationPane();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: 400),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceContainerLow,
            AppColors.deepNight,
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient glow
          Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primaryContainer.withOpacity(0.25),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                      color:
                          AppColors.primary.withOpacity(0.3)),
                  boxShadow: AppColors.primaryGlow,
                ),
                child: Icon(Icons.folder_rounded,
                    size: 64, color: AppColors.primary),
              ),
              SizedBox(height: 28),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final icon in [
                    Icons.movie_outlined,
                    Icons.play_circle_outline,
                    Icons.theaters_outlined,
                  ])
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(icon,
                          size: 24,
                          color: AppColors.onSurfaceVariant
                              .withOpacity(0.5)),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ContentPane extends StatelessWidget {
  _ContentPane({
    required this.requesting,
    required this.denied,
    required this.onAllow,
    required this.onSkip,
    required this.onOpenSettings,
  });

  final bool requesting;
  final bool denied;
  final VoidCallback onAllow;
  final VoidCallback onSkip;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App icon badge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color:
                      AppColors.primaryContainer.withOpacity(0.3),
                  blurRadius: 24,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Icon(Icons.snippet_folder_rounded,
                color: AppColors.primary, size: 28),
          ),
          SizedBox(height: 32),
          Text(
            'Access your Videos',
            style: AppTypography.headlineLg
                .copyWith(letterSpacing: -0.5),
          ),
          SizedBox(height: 16),
          Text(
            'Luvio Player needs access to your device\'s storage to scan '
            'for video files and build your offline library. Your media '
            'never leaves your device.',
            style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant),
          ),
          SizedBox(height: 40),
          _DetailRow(
            icon: Icons.movie_outlined,
            title: 'Local Playback',
            message:
                'Finds MP4, MKV, and other video formats on your internal storage and SD card.',
          ),
          SizedBox(height: 24),
          _DetailRow(
            icon: Icons.offline_pin_outlined,
            title: '100% Offline',
            message:
                'All scanning happens locally. No internet connection is required.',
          ),
          SizedBox(height: 48),
          // Actions row above a subtle top border
          Container(
            padding: EdgeInsets.only(top: 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                    color: Colors.white.withOpacity(0.05)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: AppColors.primaryGlow,
                    ),
                    child: FilledButton(
                      onPressed: requesting ? null : onAllow,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        foregroundColor:
                            AppColors.onPrimaryContainer,
                        minimumSize: Size.fromHeight(48),
                        shape: StadiumBorder(),
                        textStyle: AppTypography.labelLg,
                      ),
                      child: requesting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors
                                      .onPrimaryContainer),
                            )
                          : Text('Continue'),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSkip,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.onSurface,
                      minimumSize: Size.fromHeight(48),
                      shape: StadiumBorder(),
                      side: BorderSide(
                          color: AppColors.outlineVariant,
                          width: 2),
                      textStyle: AppTypography.labelLg,
                    ),
                    child: Text('Not Now'),
                  ),
                ),
              ],
            ),
          ),
          if (denied) ...[
            SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: onOpenSettings,
                icon: Icon(Icons.settings, size: 18),
                label: Text('Open system app settings'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  _DetailRow({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(icon, color: AppColors.secondary, size: 24),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: AppTypography.labelLg.copyWith(
                      color: AppColors.onSurface,
                      fontWeight: FontWeight.w600)),
              SizedBox(height: 4),
              Text(
                message,
                style: AppTypography.labelLg.copyWith(
                    fontWeight: FontWeight.w400,
                    color: AppColors.onSurfaceVariant
                        .withOpacity(0.8)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
