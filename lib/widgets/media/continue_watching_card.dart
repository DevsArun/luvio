import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../models/video_item.dart';
import 'video_thumbnail_image.dart';

/// 400×225 hero resume card from the reference home dashboard:
/// rounded-3xl thumbnail with bottom gradient, glowing 4px progress bar,
/// tertiary category label, headline title and "position / duration" line.
class ContinueWatchingCard extends StatelessWidget {
  const ContinueWatchingCard({
    super.key,
    required this.video,
    required this.onTap,
    this.width = 400,
  });

  final VideoItem video;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final effectiveWidth =
        screenW < 600 ? (screenW - 88).clamp(240.0, width) : width;
    return SizedBox(
      width: effectiveWidth,
      height: effectiveWidth * 9 / 16,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: 0.8,
                child: VideoThumbnailImage(video: video),
              ),
              // Bottom legibility gradient
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.9),
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              // Subtle border
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.05)),
                ),
              ),
              // Center glass play button
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.card.withOpacity(0.8),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 36),
                ),
              ),
              // Text block
              Positioned(
                left: 24,
                right: 24,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.folderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelMd
                          .copyWith(color: AppColors.tertiary),
                    ),
                    SizedBox(height: 4),
                    Text(
                      video.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headlineMd
                          .copyWith(color: Colors.white),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${Formatters.duration(video.position)} / ${Formatters.duration(video.duration)}',
                      style: AppTypography.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              // Glowing progress bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SizedBox(
                  height: 4,
                  child: Stack(
                    children: [
                      Container(color: Colors.white.withOpacity(0.2)),
                      FractionallySizedBox(
                        widthFactor: video.progress.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryContainer
                                    .withOpacity(0.8),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
