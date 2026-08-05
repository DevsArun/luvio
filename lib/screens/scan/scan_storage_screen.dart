import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../models/video_item.dart';
import '../../providers/library_provider.dart';
import '../../widgets/common/badge_chip.dart';
import '../../widgets/common/circle_icon_button.dart';
import '../../widgets/media/video_thumbnail_image.dart';

/// Scan Storage — fullscreen route with the 320px circular progress ring
/// (pulsing search icon + ping dot + orbiting particles), device cards on the
/// left and the live "Recently Found" feed on the right, per the reference.
class ScanStorageScreen extends StatefulWidget {
  const ScanStorageScreen({super.key});

  @override
  State<ScanStorageScreen> createState() => _ScanStorageScreenState();
}

class _ScanStorageScreenState extends State<ScanStorageScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: Duration(seconds: 4),
  )..repeat();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final library = context.read<LibraryProvider>();
      if (!library.scanning) library.startScan();
    });
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final wide = MediaQuery.sizeOf(context).width >= 1150;

    final leftColumn = _ProgressColumn(spin: _spin, library: library);
    final rightColumn = _FoundColumn(spin: _spin, library: library);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(32, 20, 32, 0),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Back',
                    glass: true,
                    border: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  SizedBox(width: 20),
                  Text('Scan Storage',
                      style: AppTypography.headlineLg
                          .copyWith(color: AppColors.primary)),
                ],
              ),
            ),
            Expanded(
              child: wide
                  ? Padding(
                      padding: EdgeInsets.fromLTRB(32, 24, 32, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 5, child: leftColumn),
                          SizedBox(width: 32),
                          Expanded(flex: 7, child: rightColumn),
                        ],
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(32, 24, 32, 24),
                      children: [
                        leftColumn,
                        SizedBox(height: 32),
                        SizedBox(height: 480, child: rightColumn),
                      ],
                    ),
            ),
            // Footer: Stop Scan
            Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: library.scanning
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(
                              color: AppColors.error.withOpacity(0.5)),
                          minimumSize: Size(220, 56),
                        ),
                        onPressed: () =>
                            context.read<LibraryProvider>().stopScan(),
                        icon: Icon(Icons.stop_circle_outlined),
                        label: Text('Stop Scan'),
                      )
                    : FilledButton.icon(
                        style: FilledButton.styleFrom(
                            minimumSize: Size(220, 56)),
                        onPressed: () =>
                            context.read<LibraryProvider>().startScan(),
                        icon: Icon(Icons.radar),
                        label: Text('Scan Again'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Left: ring + devices
// ---------------------------------------------------------------------------

class _ProgressColumn extends StatelessWidget {
  _ProgressColumn({required this.spin, required this.library});

  final AnimationController spin;
  final LibraryProvider library;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 320,
          height: 320,
          child: AnimatedBuilder(
            animation: spin,
            builder: (context, _) => Stack(
              alignment: Alignment.center,
              children: [
                // Ring
                CustomPaint(
                  size: Size(320, 320),
                  painter: _RingPainter(
                    fraction: library.scanning
                        ? null
                        : (library.videos.isEmpty ? 0.0 : 1.0),
                    rotation: spin.value,
                  ),
                ),
                // Inner pulsing disc
                _PulsingDisc(scanning: library.scanning),
                // Orbiting particles
                for (var i = 0; i < 3; i++)
                  Transform.rotate(
                    angle: spin.value * 2 * pi + i * 2 * pi / 3,
                    child: Align(
                      alignment: Alignment(0, -0.92),
                      child: Container(
                        width: 8 + i * 2.0,
                        height: 8 + i * 2.0,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.tertiary
                              .withOpacity(0.5 + i * 0.15),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  AppColors.tertiary.withOpacity(0.5),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: 20),
        Text(
          library.scanning ? 'SCANNING' : 'SCAN COMPLETE',
          style: AppTypography.labelLg.copyWith(
            color: library.scanning
                ? AppColors.primary
                : AppColors.tertiary,
            letterSpacing: 3,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 32),
        // Device cards
        for (final volume in library.volumes)
          Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: _DeviceCard(
              name: volume.name,
              path: volume.path,
              removable: volume.isRemovable,
              scanning: library.scanning,
              filesFound: library.videos
                  .where((v) => v.path.startsWith(volume.path))
                  .length,
            ),
          ),
      ],
    );
  }
}

class _PulsingDisc extends StatefulWidget {
  _PulsingDisc({required this.scanning});

  final bool scanning;

  @override
  State<_PulsingDisc> createState() => _PulsingDiscState();
}

class _PulsingDiscState extends State<_PulsingDisc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => Container(
        width: 256,
        height: 256,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceContainer.withOpacity(0.7),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
          boxShadow: widget.scanning
              ? [
                  BoxShadow(
                    color: AppColors.primaryContainer
                        .withOpacity(0.10 + _pulse.value * 0.20),
                    blurRadius: 48,
                    spreadRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Icon(
          widget.scanning ? Icons.search : Icons.check_circle_outline,
          size: 72 + (widget.scanning ? _pulse.value * 8 : 0),
          color: widget.scanning
              ? AppColors.primary.withOpacity(0.8)
              : AppColors.tertiary,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.rotation});

  /// null while scanning (indeterminate sweep), else 0..1.
  final double? fraction;
  final double rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = AppColors.surfaceContainerHighest.withOpacity(0.6);
    canvas.drawCircle(center, radius, track);

    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * pi,
        transform: GradientRotation(rotation * 2 * pi),
        colors: [
          AppColors.tertiaryContainer,
          AppColors.primaryContainer,
          AppColors.tertiaryContainer,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    if (fraction == null) {
      // Indeterminate 100-degree sweep that rotates.
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        rotation * 2 * pi,
        pi * 0.55,
        false,
        progress,
      );
    } else {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * fraction!,
        false,
        progress,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.rotation != rotation || oldDelegate.fraction != fraction;
}

class _DeviceCard extends StatelessWidget {
  _DeviceCard({
    required this.name,
    required this.path,
    required this.removable,
    required this.scanning,
    required this.filesFound,
  });

  final String name;
  final String path;
  final bool removable;
  final bool scanning;
  final int filesFound;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer
            .withOpacity(scanning ? 0.7 : 0.45),
        borderRadius: AppRadius.card,
        border: Border.all(
          color: scanning
              ? AppColors.primary.withOpacity(0.25)
              : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Opacity(
        opacity: scanning ? 1.0 : 0.7,
        child: Row(
          children: [
            Icon(
              removable ? Icons.sd_card_outlined : Icons.smartphone,
              size: 24,
              color: removable ? AppColors.secondary : AppColors.primary,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: AppTypography.bodyMd
                          .copyWith(fontWeight: FontWeight.w600)),
                  SizedBox(height: 3),
                  Text(
                    scanning ? path : '$filesFound files found',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.labelMd.copyWith(
                        color: AppColors.onSurfaceVariant
                            .withOpacity(0.55)),
                  ),
                  if (scanning) ...[
                    SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        backgroundColor: Color(0x33FFFFFF),
                        color: AppColors.primaryContainer,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 12),
            if (!scanning)
              Icon(Icons.check_circle,
                  size: 22, color: AppColors.tertiary),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Right: live found feed
// ---------------------------------------------------------------------------

class _FoundColumn extends StatelessWidget {
  _FoundColumn({required this.spin, required this.library});

  final AnimationController spin;
  final LibraryProvider library;

  @override
  Widget build(BuildContext context) {
    final found = library.recentlyAdded.take(30).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Recently Found',
                      style: AppTypography.headlineMd),
                  SizedBox(height: 4),
                  Text(
                    library.scanning
                        ? 'Populating library in real-time'
                        : 'Library is up to date',
                    style: AppTypography.labelMd.copyWith(
                        color: AppColors.onSurfaceVariant
                            .withOpacity(0.6)),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh.withOpacity(0.6),
                borderRadius: AppRadius.pill,
                border:
                    Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (library.scanning)
                    RotationTransition(
                      turns: spin,
                      child: Icon(Icons.sync,
                          size: 16, color: AppColors.primary),
                    )
                  else
                    Icon(Icons.check,
                        size: 16, color: AppColors.tertiary),
                  SizedBox(width: 8),
                  Text(
                    '${library.videos.length} Files',
                    style: AppTypography.labelLg
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        Expanded(
          child: found.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (library.scanning) ...[
                        // Skeleton rows while the first files stream in.
                        for (var i = 0; i < 3; i++)
                          _SkeletonRow(),
                      ] else
                        Text(
                          'No media files found yet.',
                          style: AppTypography.bodyMd.copyWith(
                              color: AppColors.onSurfaceVariant
                                  .withOpacity(0.6)),
                        ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: found.length + (library.scanning ? 1 : 0),
                  separatorBuilder: (_, __) => SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index >= found.length) {
                      return _SkeletonRow();
                    }
                    return _FoundRow(video: found[index], index: index);
                  },
                ),
        ),
      ],
    );
  }
}

class _FoundRow extends StatelessWidget {
  _FoundRow({required this.video, required this.index});

  final VideoItem video;
  final int index;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.medium,
      curve: AppMotion.emphasized,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(24 * (1 - t), 0),
          child: child,
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer.withOpacity(0.5),
          borderRadius: AppRadius.card,
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 128,
              height: 80,
              child: ClipRRect(
                borderRadius: AppRadius.chip,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoThumbnailImage(video: video),
                    if (video.duration != null)
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: BadgeChip.duration(
                            Formatters.duration(video.duration)),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(video.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMd
                          .copyWith(fontWeight: FontWeight.w600)),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${video.folderName} • ${Formatters.bytes(video.sizeBytes)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelMd.copyWith(
                              color: AppColors.onSurfaceVariant
                                  .withOpacity(0.55)),
                        ),
                      ),
                      if (video.resolutionBadge != null) ...[
                        SizedBox(width: 10),
                        BadgeChip(
                          label: video.resolutionBadge!,
                          color: Color(0x2675D1FF),
                          textColor: AppColors.tertiary,
                        ),
                      ],
                    ],
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

class _SkeletonRow extends StatefulWidget {
  _SkeletonRow();

  @override
  State<_SkeletonRow> createState() => _SkeletonRowState();
}

class _SkeletonRowState extends State<_SkeletonRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        final opacity = 0.35 + _shimmer.value * 0.25;
        Widget bar(double width, double height) => Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08 * opacity * 2),
                borderRadius: BorderRadius.circular(6),
              ),
            );
        return Container(
          padding: EdgeInsets.all(12),
          margin: EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer.withOpacity(0.35),
            borderRadius: AppRadius.card,
          ),
          child: Row(
            children: [
              Container(
                width: 128,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06 * opacity * 2),
                  borderRadius: AppRadius.chip,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(double.infinity, 14),
                    SizedBox(height: 10),
                    bar(160, 10),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
