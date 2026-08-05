import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../models/video_item.dart';
import '../common/badge_chip.dart';
import 'video_thumbnail_image.dart';

/// Grid card: 16:9 thumbnail with duration/resolution badges, watch
/// progress bar, title and metadata. Subtle scale on hover/press.
class VideoCard extends StatefulWidget {
  const VideoCard({
    super.key,
    required this.video,
    required this.onTap,
    this.onMore,
  });

  final VideoItem video;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final video = widget.video;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.ease,
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onMore,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: AppRadius.card,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      VideoThumbnailImage(video: video),
                      // Bottom scrim for badge legibility.
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.55),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        top: 8,
                        child: BadgeChip(
                          label: video.resolutionBadge ?? 'SD',
                          glass: true,
                          textColor: Colors.white,
                        ),
                      ),
                      if (video.isNew)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: BadgeChip(
                            label: 'NEW',
                            color: AppColors.tertiaryContainer,
                            textColor: AppColors.onTertiaryContainer,
                          ),
                        ),
                      if (video.durationMs > 0)
                        Positioned(
                          right: 8,
                          bottom: video.inProgress ? 12 : 8,
                          child: BadgeChip.duration(Formatters.duration(video.duration)),
                        ),
                      if (video.inProgress)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: SizedBox(
                            height: 4,
                            child: Stack(
                              children: [
                                Container(
                                    color:
                                        Colors.white.withOpacity(0.25)),
                                FractionallySizedBox(
                                  widthFactor: video.progress,
                                  child: Container(
                                      color: AppColors.primaryContainer),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyLg
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${Formatters.bytes(video.sizeBytes)} • ${Formatters.relativeDate(video.modified)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.onSurfaceVariant
                                .withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onMore != null)
                    IconButton(
                      onPressed: widget.onMore,
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        Icons.more_vert,
                        size: 20,
                        color: AppColors.onSurfaceVariant
                            .withOpacity(0.7),
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
}
