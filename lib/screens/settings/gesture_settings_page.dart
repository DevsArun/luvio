import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/common/circle_icon_button.dart';

/// Gesture Settings — toggles for brightness / volume / seek / double-tap
/// gestures plus the double-tap seek amount selector.
class GestureSettingsPage extends StatelessWidget {
  const GestureSettingsPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    Widget row({
      required IconData icon,
      required String title,
      required String subtitle,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) {
      return SwitchListTile(
        value: value,
        onChanged: onChanged,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.panel),
        contentPadding:
            EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        secondary: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: AppColors.secondary),
        ),
        title: Text(title, style: AppTypography.bodyLg),
        subtitle: Text(
          subtitle,
          style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurfaceVariant.withOpacity(0.6)),
        ),
      );
    }

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView(
        padding: EdgeInsets.fromLTRB(32, 48, 32, 96),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 896),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleIconButton(
                        icon: Icons.arrow_back,
                        tooltip: 'Back to Settings',
                        glass: true,
                        border: true,
                        onPressed: onBack,
                      ),
                      SizedBox(width: 20),
                      Text('Gesture Controls',
                          style: AppTypography.headlineLg),
                    ],
                  ),
                  SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.only(left: 68),
                    child: Text(
                      'Control playback with touch gestures on the player surface.',
                      style: AppTypography.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant
                              .withOpacity(0.7)),
                    ),
                  ),
                  SizedBox(height: 28),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer.withOpacity(0.55),
                      borderRadius: AppRadius.panel,
                      border: Border.all(
                          color: Colors.white.withOpacity(0.04)),
                    ),
                    child: Column(
                      children: [
                        row(
                          icon: Icons.light_mode_outlined,
                          title: 'Brightness Gesture',
                          subtitle:
                              'Swipe vertically on the left half of the screen',
                          value: settings.brightnessGesture,
                          onChanged: settings.setBrightnessGesture,
                        ),
                        Divider(
                            height: 1,
                            indent: 76,
                            color: Colors.white.withOpacity(0.04)),
                        row(
                          icon: Icons.volume_up_outlined,
                          title: 'Volume Gesture',
                          subtitle:
                              'Swipe vertically on the right half of the screen',
                          value: settings.volumeGesture,
                          onChanged: settings.setVolumeGesture,
                        ),
                        Divider(
                            height: 1,
                            indent: 76,
                            color: Colors.white.withOpacity(0.04)),
                        row(
                          icon: Icons.swipe_outlined,
                          title: 'Seek Gesture',
                          subtitle: 'Swipe horizontally to scrub through the video',
                          value: settings.seekGesture,
                          onChanged: settings.setSeekGesture,
                        ),
                        Divider(
                            height: 1,
                            indent: 76,
                            color: Colors.white.withOpacity(0.04)),
                        row(
                          icon: Icons.touch_app_outlined,
                          title: 'Double-Tap Seek',
                          subtitle:
                              'Double-tap screen edges to jump backward / forward',
                          value: settings.doubleTapGesture,
                          onChanged: settings.setDoubleTapGesture,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer.withOpacity(0.55),
                      borderRadius: AppRadius.panel,
                      border: Border.all(
                          color: Colors.white.withOpacity(0.04)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Double-Tap Seek Amount',
                            style: AppTypography.bodyLg),
                        SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          children: [
                            for (final seconds in [5, 10, 15, 30])
                              ChoiceChip(
                                label: Text('${seconds}s'),
                                selected: settings.doubleTapSeconds ==
                                    seconds,
                                selectedColor: AppColors.primaryContainer,
                                labelStyle: AppTypography.labelLg.copyWith(
                                  color: settings.doubleTapSeconds ==
                                          seconds
                                      ? AppColors.onPrimaryContainer
                                      : AppColors.onSurfaceVariant,
                                ),
                                onSelected: (_) => settings
                                    .setDoubleTapSeconds(seconds),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
