import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/app_enums.dart';
import '../../providers/player_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/shell/top_bar.dart';

/// 10-band equalizer with presets, master gain, bass boost and
/// virtualizer dials. Changes apply live to the active player.
class EqualizerScreen extends StatelessWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final player = context.read<PlayerProvider>();

    void apply() => player.applyEqualizer(settings);

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.of(context).size.width < 600
                ? 16.0
                : AppSpacing.containerPadding,
            TopBar.height + 24,
            MediaQuery.of(context).size.width < 600
                ? 16.0
                : AppSpacing.containerPadding,
            48,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MicroHeader('AUDIO'),
                    SizedBox(height: 8),
                    SectionHeader(
                      title: 'Equalizer',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            settings.eqEnabled ? 'On' : 'Off',
                            style: AppTypography.labelLg.copyWith(
                              color: settings.eqEnabled
                                  ? AppColors.primary
                                  : AppColors.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(width: 12),
                          Switch(
                            value: settings.eqEnabled,
                            onChanged: (v) async {
                              await settings.setEqEnabled(v);
                              apply();
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Shape the sound of every video — changes apply instantly.',
                      style: AppTypography.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant
                              .withOpacity(0.7)),
                    ),
                    SizedBox(height: 28),
                    // --- Presets --------------------------------------------
                    MicroHeader('PRESETS'),
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final preset in EqPreset.values)
                          ChoiceChip(
                            label: Text(preset.label),
                            selected:
                                settings.eqPreset == preset,
                            onSelected: settings.eqEnabled
                                ? (_) async {
                                    await settings
                                        .applyEqPreset(preset);
                                    apply();
                                  }
                                : null,
                          ),
                      ],
                    ),
                    SizedBox(height: 28),
                    // --- Bands ----------------------------------------------
                    AnimatedOpacity(
                      duration: AppMotion.fast,
                      opacity: settings.eqEnabled ? 1 : 0.4,
                      child: IgnorePointer(
                        ignoring: !settings.eqEnabled,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              vertical: 28, horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: AppRadius.container,
                            border: Border.all(
                                color: Colors.white
                                    .withOpacity(0.05)),
                          ),
                          child: SizedBox(
                            height: 320,
                            child: Row(
                              children: [
                                for (var band = 0;
                                    band < kEqBandLabels.length;
                                    band++)
                                  Expanded(
                                    child: _BandSlider(
                                      label:
                                          kEqBandLabels[band],
                                      value: settings
                                          .eqBands[band],
                                      onChanged: (v) async {
                                        await settings
                                            .setEqBand(band, v);
                                        apply();
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 28),
                    // --- Dials ----------------------------------------------
                    AnimatedOpacity(
                      duration: AppMotion.fast,
                      opacity: settings.eqEnabled ? 1 : 0.4,
                      child: IgnorePointer(
                        ignoring: !settings.eqEnabled,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final narrow =
                                constraints.maxWidth < 720;
                            final dials = [
                              _KnobTile(
                                label: 'Master Gain',
                                value: settings.eqMasterGain,
                                onChanged: (v) async {
                                  await settings
                                      .setEqMasterGain(v);
                                  apply();
                                },
                              ),
                              _KnobTile(
                                label: 'Bass Boost',
                                value: settings.eqBassBoost,
                                onChanged: (v) async {
                                  await settings
                                      .setEqBassBoost(v);
                                  apply();
                                },
                              ),
                              _KnobTile(
                                label: 'Virtualizer',
                                value: settings.eqVirtualizer,
                                onChanged: (v) async {
                                  await settings
                                      .setEqVirtualizer(v);
                                  apply();
                                },
                              ),
                            ];
                            if (narrow) {
                              return Column(
                                children: [
                                  for (final dial in dials)
                                    Padding(
                                      padding:
                                          EdgeInsets.only(
                                              bottom: 16),
                                      child: dial,
                                    ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                for (final dial in dials) ...[
                                  Expanded(child: dial),
                                  if (dial != dials.last)
                                    SizedBox(width: 16),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 28),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton.icon(
                        onPressed: settings.eqEnabled
                            ? () async {
                                await settings.resetEqBands();
                                apply();
                              }
                            : null,
                        icon: Icon(Icons.refresh,
                            size: 18),
                        label: Text('Reset Bands'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
            top: 0, left: 0, right: 0, child: TopBar()),
      ],
    );
  }
}

class _BandSlider extends StatelessWidget {
  _BandSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${value >= 0 ? '+' : ''}${value.toStringAsFixed(0)} dB',
          style: AppTypography.labelMd.copyWith(
            color: value == 0
                ? AppColors.onSurfaceVariant.withOpacity(0.6)
                : AppColors.primary,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        SizedBox(height: 8),
        Expanded(
          child: RotatedBox(
            quarterTurns: -1,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: RoundSliderThumbShape(
                    enabledThumbRadius: 9),
              ),
              child: Slider(
                value: value.clamp(-15, 15),
                min: -15,
                max: 15,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: AppTypography.labelMd.copyWith(
              color:
                  AppColors.onSurfaceVariant.withOpacity(0.7)),
        ),
      ],
    );
  }
}

/// Circular dial tile: drag vertically (or use the slider) to adjust.
class _KnobTile extends StatelessWidget {
  _KnobTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.container,
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onVerticalDragUpdate: (details) {
              onChanged((value - details.delta.dy / 150)
                  .clamp(0.0, 1.0));
            },
            child: CustomPaint(
              size: Size(120, 120),
              painter: _KnobPainter(value: value),
              child: SizedBox(
                width: 120,
                height: 120,
                child: Center(
                  child: Text(
                    '${(value * 100).round()}',
                    style: AppTypography.headlineMd.copyWith(
                      fontFeatures: [
                        FontFeature.tabularFigures()
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(label,
              style: AppTypography.bodyMd
                  .copyWith(fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Slider(
            value: value.clamp(0.0, 1.0),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _KnobPainter extends CustomPainter {
  _KnobPainter({required this.value});

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 8;

    // 270° sweep starting bottom-left.
    final startAngle = 3 * math.pi / 4;
    final maxSweep = 3 * math.pi / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withOpacity(0.08);
    canvas.drawArc(rect, startAngle, maxSweep, false, track);

    if (value > 0) {
      final fill = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + maxSweep,
          colors: [
            AppColors.tertiary,
            AppColors.primaryContainer,
          ],
          transform: GradientRotation(startAngle),
        ).createShader(rect);
      canvas.drawArc(
          rect, startAngle, maxSweep * value, false, fill);
    }

    // Indicator dot.
    final angle = startAngle + maxSweep * value;
    final dotCenter = Offset(
      center.dx + (radius - 0) * math.cos(angle),
      center.dy + (radius - 0) * math.sin(angle),
    );
    canvas.drawCircle(
      dotCenter,
      6,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_KnobPainter oldDelegate) =>
      oldDelegate.value != value;
}
