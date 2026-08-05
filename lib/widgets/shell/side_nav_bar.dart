import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../providers/player_provider.dart';
import '../../screens/dialogs/sleep_timer_dialog.dart';
import '../../screens/shell/app_shell.dart';

/// 288px side navigation — brand block with "Premium Offline Media"
/// subtitle, a Scan Storage shortcut, the five primary sections with a
/// solid primary-container active pill, and footer rows for Sleep Timer
/// and Equalizer, exactly like the reference shell.
class SideNavBar extends StatelessWidget {
  const SideNavBar({
    super.key,
    required this.section,
    required this.onSectionSelected,
  });

  static const double width = 288;

  final AppSection section;
  final ValueChanged<AppSection> onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.92),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        boxShadow: AppColors.ambientShadow,
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Brand block ---------------------------------------------
            Padding(
              padding: EdgeInsets.fromLTRB(32, 32, 32, 8),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: AppColors.primaryGlow,
                    ),
                    child: Icon(Icons.play_circle_fill,
                        color: AppColors.onPrimaryContainer, size: 28),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Luvio Player',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.headlineMd.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Premium Offline Media',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelMd.copyWith(
                              color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // --- Scan Storage shortcut ------------------------------------
            Padding(
              padding: EdgeInsets.fromLTRB(32, 20, 32, 8),
              child: Material(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () =>
                      Navigator.of(context).pushNamed(Routes.scan),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              AppColors.outline.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search,
                            size: 20, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Scan Storage',
                            style: AppTypography.labelLg.copyWith(
                                color: AppColors.primary)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            // --- Primary sections -----------------------------------------
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _NavTile(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home,
                    label: 'Home',
                    active: section == AppSection.home,
                    onTap: () => onSectionSelected(AppSection.home),
                  ),
                  _NavTile(
                    icon: Icons.video_library_outlined,
                    activeIcon: Icons.video_library,
                    label: 'Library',
                    active: section == AppSection.library,
                    onTap: () =>
                        onSectionSelected(AppSection.library),
                  ),
                  _NavTile(
                    icon: Icons.library_music_outlined,
                    activeIcon: Icons.library_music,
                    label: 'Audio',
                    active: section == AppSection.audio,
                    onTap: () =>
                        onSectionSelected(AppSection.audio),
                  ),
                  _NavTile(
                    icon: Icons.folder_outlined,
                    activeIcon: Icons.folder,
                    label: 'Folders',
                    active: section == AppSection.folders,
                    onTap: () =>
                        onSectionSelected(AppSection.folders),
                  ),
                  _NavTile(
                    icon: Icons.folder_copy_outlined,
                    activeIcon: Icons.folder_copy,
                    label: 'Files',
                    active: section == AppSection.files,
                    onTap: () =>
                        onSectionSelected(AppSection.files),
                  ),
                  _NavTile(
                    icon: Icons.lock_outline,
                    activeIcon: Icons.lock,
                    label: 'Vault',
                    active: section == AppSection.vault,
                    onTap: () => onSectionSelected(AppSection.vault),
                  ),
                  _NavTile(
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings,
                    label: 'Settings',
                    active: section == AppSection.settings,
                    onTap: () =>
                        onSectionSelected(AppSection.settings),
                  ),
                ],
              ),
            ),
            // --- Footer: Sleep Timer + Equalizer ---------------------------
            Container(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                      color: Colors.white.withOpacity(0.05)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _NavTile(
                    icon: Icons.bedtime_outlined,
                    activeIcon: Icons.bedtime,
                    label: player.sleepTimerActive
                        ? 'Sleep • ${Formatters.duration(player.sleepRemaining!)}'
                        : 'Sleep Timer',
                    active: false,
                    compact: true,
                    tinted: player.sleepTimerActive,
                    onTap: () => showSleepTimerDialog(context),
                  ),
                  _NavTile(
                    icon: Icons.equalizer,
                    activeIcon: Icons.equalizer,
                    label: 'Equalizer',
                    active: section == AppSection.equalizer,
                    compact: true,
                    onTap: () =>
                        onSectionSelected(AppSection.equalizer),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Version 2.6.0',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelMd.copyWith(
                        color: AppColors.onSurfaceVariant
                            .withOpacity(0.4)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  _NavTile({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
    this.compact = false,
    this.tinted = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final bool compact;
  final bool tinted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fg = active
        ? AppColors.onPrimaryContainer
        : (tinted ? AppColors.primary : AppColors.onSurfaceVariant);
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Material(
        color: active
            ? AppColors.primaryContainer
            : (tinted
                ? AppColors.primaryContainer.withOpacity(0.15)
                : Colors.transparent),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: Colors.white.withOpacity(0.05),
          child: Container(
            height: compact ? 48 : 56,
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Icon(active ? activeIcon : icon, size: 24, color: fg),
                SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelLg.copyWith(
                      color: active ? AppColors.onPrimaryContainer : fg,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
