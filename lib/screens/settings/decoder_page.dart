import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/app_enums.dart';
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/common/circle_icon_button.dart';

/// Hardware / Software decoder selection with explanations of each mode.
class DecoderPage extends StatelessWidget {
  const DecoderPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    Widget option({
      required DecoderMode mode,
      required String title,
      required String badge,
      required String description,
      required IconData icon,
    }) {
      final active = settings.decoderMode == mode;
      return Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Material(
          color: active
              ? AppColors.primaryContainer.withOpacity(0.12)
              : AppColors.surfaceContainer.withOpacity(0.55),
          borderRadius: AppRadius.panel,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              settings.setDecoderMode(mode);
              context.read<PlayerProvider>().applyDecoderMode(mode);
            },
            child: Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: AppRadius.panel,
                border: Border.all(
                  color: active
                      ? AppColors.primary.withOpacity(0.4)
                      : Colors.white.withOpacity(0.04),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: (active
                              ? AppColors.primary
                              : AppColors.secondary)
                          .withOpacity(0.15),
                      borderRadius: AppRadius.chip,
                    ),
                    child: Icon(icon,
                        size: 24,
                        color: active
                            ? AppColors.primary
                            : AppColors.secondary),
                  ),
                  SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(title, style: AppTypography.bodyLg),
                            SizedBox(width: 12),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHighest
                                    .withOpacity(0.8),
                                borderRadius: AppRadius.pill,
                              ),
                              child: Text(
                                badge,
                                style: AppTypography.labelMd.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6),
                        Text(
                          description,
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.onSurfaceVariant
                                .withOpacity(0.7),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  Radio<DecoderMode>(
                    value: mode,
                    groupValue: settings.decoderMode,
                    onChanged: (v) {
                      if (v == null) return;
                      settings.setDecoderMode(v);
                      context.read<PlayerProvider>().applyDecoderMode(v);
                    },
                  ),
                ],
              ),
            ),
          ),
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
                      Text('Video Decoder',
                          style: AppTypography.headlineLg),
                    ],
                  ),
                  SizedBox(height: 8),
                  Padding(
                    padding: EdgeInsets.only(left: 68),
                    child: Text(
                      'Choose how videos are decoded on this tablet. Applies to the next video you play.',
                      style: AppTypography.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant
                              .withOpacity(0.7)),
                    ),
                  ),
                  SizedBox(height: 28),
                  option(
                    mode: DecoderMode.hardware,
                    title: 'Hardware Decoder',
                    badge: 'HW',
                    icon: Icons.memory,
                    description:
                        'Uses the tablet’s dedicated video chip. Best battery life '
                        'and smoothest playback for common formats — recommended '
                        'for Fire tablets.',
                  ),
                  option(
                    mode: DecoderMode.hardwarePlus,
                    title: 'Hardware+ Decoder',
                    badge: 'HW+',
                    icon: Icons.bolt,
                    description:
                        'Aggressive hardware decoding for maximum performance. May '
                        'cause artifacts on a few unusual files — switch back to HW '
                        'if you see glitches.',
                  ),
                  option(
                    mode: DecoderMode.software,
                    title: 'Software Decoder',
                    badge: 'SW',
                    icon: Icons.developer_board,
                    description:
                        'Decodes entirely on the CPU. Maximum compatibility with '
                        'rare codecs and damaged files, at the cost of battery and '
                        'heat on long sessions.',
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
