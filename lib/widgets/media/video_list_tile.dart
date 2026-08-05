import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../models/video_item.dart';
import '../common/badge_chip.dart';
import 'video_thumbnail_image.dart';

/// List row: 128×72 thumbnail, title, metadata, progress + actions.
class VideoListTile extends StatelessWidget {
  const VideoListTile({
    super.key,
    required this.video,
    required this.onTap,
    this.onMore,
    this.selectionMode = false,
    this.selected = false,
  });

  final VideoItem video;
  final VoidCallback onTap;
  final VoidCallback? onMore;
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primaryContainer.withOpacity(0.15)
          : AppColors.surfaceContainerLow,
      borderRadius: AppRadius.card,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onMore,
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              if (selectionMode) ...[
                Icon(
                  selected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: selected
                      ? AppColors.primary
                      : AppColors.outline,
                ),
                SizedBox(width: 12),
              ],
              ClipRRect(
                borderRadius: AppRadius.panel,
                child: SizedBox(
                  width: 128,
                  height: 72,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      VideoThumbnailImage(video: video),
                      if (video.durationMs > 0)
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: BadgeChip.duration(Formatters.duration(video.duration)),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      video.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyLg
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 6),
                    Text(
                      [
                        if (video.durationMs > 0)
                          Formatters.durationVerbose(video.duration),
                        Formatters.bytes(video.sizeBytes),
                        video.folderName,
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.onSurfaceVariant
                            .withOpacity(0.7),
                      ),
                    ),
                    if (video.inProgress) ...[
                      SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: video.progress,
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 8),
              if (!selectionMode && onMore != null)
                IconButton(
                  onPressed: onMore,
                  tooltip: 'More options',
                  icon: Icon(Icons.more_vert,
                      color: AppColors.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
