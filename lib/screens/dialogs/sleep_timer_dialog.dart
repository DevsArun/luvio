import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../providers/player_provider.dart';

/// Sleep timer dialog: glowing countdown ring, duration presets,
/// "stop after current video" toggle, start/cancel actions.
Future<void> showSleepTimerDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => SleepTimerDialog(),
  );
}

class SleepTimerDialog extends StatefulWidget {
  const SleepTimerDialog({super.key});

  @override
  State<SleepTimerDialog> createState() => _SleepTimerDialogState();
}

class _SleepTimerDialogState extends State<SleepTimerDialog> {
  static const presets = [15, 30, 45, 60, 90];

  int _minutes = 30;
  bool _stopAfterCurrent = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final player = context.read<PlayerProvider>();
    if (player.sleepTimerActive && player.sleepTotal != null) {
      _minutes = player.sleepTotal!.inMinutes.clamp(5, 120);
      _stopAfterCurrent = player.sleepStopAfterCurrent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final active = player.sleepTimerActive;

    // Ring shows remaining fraction while running, otherwise full.
    final fraction = active &&
            player.sleepTotal != null &&
            player.sleepTotal!.inSeconds > 0
        ? (player.sleepRemaining!.inSeconds /
                player.sleepTotal!.inSeconds)
            .clamp(0.0, 1.0)
        : 1.0;

    final centerValue = active
        ? _formatRemaining(player.sleepRemaining!)
        : '$_minutes';
    final centerCaption = active ? 'REMAINING' : 'MINUTES';

    return Dialog(
      backgroundColor: AppColors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.container,
        side: BorderSide(color: Colors.white.withOpacity(0.06)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Header ------------------------------------------------
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color:
                          AppColors.primaryContainer.withOpacity(0.2),
                      borderRadius: AppRadius.panel,
                    ),
                    child: Icon(Icons.bedtime_outlined,
                        color: AppColors.primary),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sleep Timer',
                            style: AppTypography.headlineMd),
                        Text(
                          active
                              ? 'Playback will stop automatically'
                              : 'Stop playback after a set time',
                          style: AppTypography.labelMd.copyWith(
                              color: AppColors.onSurfaceVariant
                                  .withOpacity(0.7)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Close',
                    icon: Icon(Icons.close,
                        color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
              SizedBox(height: 28),
              // --- Countdown ring ------------------------------------------
              Center(
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: _RingPainter(fraction: fraction),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              centerValue,
                              style: AppTypography.displayLg.copyWith(
                                fontFeatures: [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                            Text(
                              centerCaption,
                              style: AppTypography.labelMd.copyWith(
                                letterSpacing: 2,
                                color: AppColors.onSurfaceVariant
                                    .withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              if (!active) ...[
                // --- Duration slider + presets ---------------------------
                Slider(
                  value: _minutes.toDouble(),
                  min: 5,
                  max: 120,
                  divisions: 23,
                  onChanged: (v) =>
                      setState(() => _minutes = v.round()),
                ),
                SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final preset in presets)
                      _PresetChip(
                        minutes: preset,
                        selected: _minutes == preset,
                        onTap: () =>
                            setState(() => _minutes = preset),
                      ),
                  ],
                ),
                SizedBox(height: 20),
              ],
              // --- Stop after current toggle --------------------------------
              Material(
                color: AppColors.surfaceContainer,
                borderRadius: AppRadius.panel,
                child: SwitchListTile(
                  value: active
                      ? player.sleepStopAfterCurrent
                      : _stopAfterCurrent,
                  onChanged: active
                      ? null
                      : (v) => setState(() => _stopAfterCurrent = v),
                  title: Text('Stop after current video',
                      style: AppTypography.bodyMd),
                  subtitle: Text(
                    'Let the playing video finish before stopping',
                    style: AppTypography.labelMd.copyWith(
                        color: AppColors.onSurfaceVariant
                            .withOpacity(0.6)),
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.panel),
                ),
              ),
              SizedBox(height: 28),
              // --- Actions -----------------------------------------------
              if (active)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          player.cancelSleepTimer();
                          Navigator.of(context).pop();
                        },
                        icon: Icon(Icons.timer_off_outlined,
                            size: 20),
                        label: Text('Cancel Timer'),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.of(context).pop(),
                        child: Text('Close'),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: AppRadius.pill,
                          boxShadow: AppColors.primaryGlow,
                        ),
                        child: FilledButton.icon(
                          onPressed: () {
                            player.startSleepTimer(
                              Duration(minutes: _minutes),
                              stopAfterCurrent: _stopAfterCurrent,
                            );
                            Navigator.of(context).pop();
                          },
                          icon: Icon(Icons.bedtime, size: 20),
                          label: Text('Start Timer'),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRemaining(Duration remaining) {
    if (remaining.inMinutes >= 1) return '${remaining.inMinutes}';
    return '0:${remaining.inSeconds.toString().padLeft(2, '0')}';
  }
}

/// Gradient countdown arc with a soft glow.
class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction});

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 12;
    final strokeWidth = 12.0;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.white.withOpacity(0.08);
    canvas.drawCircle(center, radius, track);

    if (fraction <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final startAngle = -math.pi / 2;
    final sweep = 2 * math.pi * fraction;

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 8
      ..strokeCap = StrokeCap.round
      ..color = AppColors.primaryContainer.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawArc(rect, startAngle, sweep, false, glow);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + 2 * math.pi,
        colors: [
          AppColors.tertiary,
          AppColors.primaryContainer,
          AppColors.primary,
        ],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(rect, startAngle, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}

class _PresetChip extends StatelessWidget {
  _PresetChip({
    required this.minutes,
    required this.selected,
    required this.onTap,
  });

  final int minutes;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primaryContainer
          : AppColors.surfaceContainerHigh,
      shape: StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding:
              EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Text(
            '$minutes min',
            style: AppTypography.labelLg.copyWith(
              color: selected
                  ? AppColors.onPrimaryContainer
                  : AppColors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
