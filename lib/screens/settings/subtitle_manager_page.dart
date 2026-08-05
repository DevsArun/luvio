import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/app_enums.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/common/section_header.dart';

/// Subtitle Manager: live preview panel plus font size, position,
/// color, background, outline and shadow customization.
class SubtitleManagerPage extends StatelessWidget {
  const SubtitleManagerPage({super.key, this.onBack});

  final VoidCallback? onBack;

  static const _sampleQuote =
      '“I’ve seen things you people wouldn’t believe.”';

  static List<Color> get _colorSwatches => <Color>[
    Color(0xFFFFFFFF), // Classic white
    Color(0xFFFCD34D), // Cinema yellow
    Color(0xFF93C5FD), // Soft blue
    AppColors.tertiary, // Luvio cyan
    Color(0xFF86EFAC), // Mint green
    Color(0xFFFDA4AF), // Rose
  ];

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    // --- Live preview text style built from current settings -----------
    final List<Shadow> shadows = [
      ...switch (settings.subtitleShadow) {
        SubtitleShadow.none => <Shadow>[],
        SubtitleShadow.subtle => [
            Shadow(
                color: Colors.black54,
                blurRadius: 4,
                offset: Offset(0, 1)),
          ],
        SubtitleShadow.heavy => [
            Shadow(
                color: Colors.black87,
                blurRadius: 10,
                offset: Offset(0, 2)),
          ],
      },
      // Fake an outline with layered shadows (matches player rendering).
      ...switch (settings.subtitleOutline) {
        SubtitleOutline.none => <Shadow>[],
        SubtitleOutline.thin => _outlineShadows(1),
        SubtitleOutline.normal => _outlineShadows(2),
        SubtitleOutline.thick => _outlineShadows(3),
      },
    ];

    final previewStyle = TextStyle(
      fontSize: settings.subtitleFontSize,
      height: 1.35,
      fontWeight: FontWeight.w600,
      color: settings.subtitleColor,
      shadows: shadows,
      backgroundColor: switch (settings.subtitleBackground) {
        SubtitleBackground.transparent => Colors.transparent,
        SubtitleBackground.translucent => Colors.black54,
        SubtitleBackground.solid => Colors.black,
      },
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.containerPadding, 8, AppSpacing.containerPadding, 48),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Preview -------------------------------------------
                MicroHeader('LIVE PREVIEW'),
                SizedBox(height: 12),
                ClipRRect(
                  borderRadius: AppRadius.container,
                  child: AspectRatio(
                    aspectRatio: 21 / 9,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF23283A),
                            Color(0xFF0B0C12),
                          ],
                        ),
                      ),
                      child: Stack(
                        children: [
                          // Subtitle positioned per vertical setting.
                          Align(
                            alignment: Alignment(
                                0,
                                (settings.subtitleVerticalPos *
                                        2) -
                                    1),
                            child: Padding(
                              padding:
                                  EdgeInsets.symmetric(
                                      horizontal: 32,
                                      vertical: 20),
                              child: Text(
                                _sampleQuote,
                                textAlign: TextAlign.center,
                                style: previewStyle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 32),
                // --- Font size -----------------------------------------
                _SettingBlock(
                  title: 'Font Size',
                  trailing:
                      '${settings.subtitleFontSize.round()} pt',
                  child: Slider(
                    value: settings.subtitleFontSize
                        .clamp(16.0, 40.0),
                    min: 16,
                    max: 40,
                    divisions: 24,
                    onChanged: settings.setSubtitleFontSize,
                  ),
                ),
                // --- Vertical position ----------------------------------
                _SettingBlock(
                  title: 'Vertical Position',
                  trailing:
                      '${(settings.subtitleVerticalPos * 100).round()}%',
                  child: Slider(
                    value: settings.subtitleVerticalPos
                        .clamp(0.5, 1.0),
                    min: 0.5,
                    max: 1.0,
                    onChanged: settings.setSubtitleVerticalPos,
                  ),
                ),
                // --- Color ----------------------------------------------
                _SettingBlock(
                  title: 'Text Color',
                  child: Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 14,
                      children: [
                        for (final swatch in _colorSwatches)
                          _ColorDot(
                            color: swatch,
                            selected: settings
                                    .subtitleColor.value ==
                                swatch.value,
                            onTap: () => settings
                                .setSubtitleColor(swatch),
                          ),
                      ],
                    ),
                  ),
                ),
                // --- Background -----------------------------------------
                _SettingBlock(
                  title: 'Background',
                  child: Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: SegmentedButton<SubtitleBackground>(
                      segments: [
                        for (final bg
                            in SubtitleBackground.values)
                          ButtonSegment(
                              value: bg,
                              label: Text(bg.label)),
                      ],
                      selected: {settings.subtitleBackground},
                      onSelectionChanged: (selection) =>
                          settings.setSubtitleBackground(
                              selection.first),
                    ),
                  ),
                ),
                // --- Outline --------------------------------------------
                _SettingBlock(
                  title: 'Outline',
                  child: Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 10,
                      children: [
                        for (final outline
                            in SubtitleOutline.values)
                          ChoiceChip(
                            label: Text(outline.label),
                            selected:
                                settings.subtitleOutline ==
                                    outline,
                            onSelected: (_) => settings
                                .setSubtitleOutline(outline),
                          ),
                      ],
                    ),
                  ),
                ),
                // --- Shadow ---------------------------------------------
                _SettingBlock(
                  title: 'Shadow',
                  child: Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 10,
                      children: [
                        for (final shadow
                            in SubtitleShadow.values)
                          ChoiceChip(
                            label: Text(shadow.label),
                            selected:
                                settings.subtitleShadow ==
                                    shadow,
                            onSelected: (_) => settings
                                .setSubtitleShadow(shadow),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 8),
                // --- External files note ---------------------------------
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: AppRadius.card,
                    border: Border.all(
                        color:
                            Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.subtitles_outlined,
                          color: AppColors.tertiary),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text('External subtitle files',
                                style: AppTypography.bodyMd
                                    .copyWith(
                                        fontWeight:
                                            FontWeight.w600)),
                            SizedBox(height: 4),
                            Text(
                              'Load .srt, .ass, .ssa, .vtt or .sub files from the player’s '
                              'menu → “Load Subtitle File”. Files named like the video '
                              '(e.g. Blade.Runner.2049.1080p.WEBRip.srt next to the .mkv) '
                              'are detected automatically by the player engine.',
                              style: AppTypography.labelMd
                                  .copyWith(
                                      color: AppColors
                                          .onSurfaceVariant
                                          .withOpacity(0.7)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static List<Shadow> _outlineShadows(double width) => [
        for (final dx in [-width, 0.0, width])
          for (final dy in [-width, 0.0, width])
            if (dx != 0 || dy != 0)
              Shadow(
                  color: Colors.black,
                  offset: Offset(dx, dy),
                  blurRadius: 0),
      ];
}

class _SettingBlock extends StatelessWidget {
  _SettingBlock({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: AppTypography.bodyLg.copyWith(
                        fontWeight: FontWeight.w600)),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: AppTypography.labelLg.copyWith(
                    color: AppColors.primary,
                    fontFeatures: [
                      FontFeature.tabularFigures()
                    ],
                  ),
                ),
            ],
          ),
          child,
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: CircleBorder(),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? AppColors.primary
                : Colors.white.withOpacity(0.15),
            width: selected ? 3 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: selected
            ? Icon(Icons.check,
                color: Colors.black87, size: 20)
            : null,
      ),
    );
  }
}
