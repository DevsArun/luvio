import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/video_item.dart';
import '../../services/thumbnail_service.dart';

/// Lazily-generated frame thumbnail with a graceful gradient fallback.
class VideoThumbnailImage extends StatelessWidget {
  const VideoThumbnailImage({
    super.key,
    required this.video,
    this.fit = BoxFit.cover,
  });

  final VideoItem video;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: ThumbnailService.instance
          .thumbnailFor(video.path, video.modified),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file != null) {
          return Image.file(
            file,
            fit: fit,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _ThumbFallback(),
          );
        }
        return _ThumbFallback();
      },
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  _ThumbFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceContainerHigh,
            AppColors.surfaceContainerLowest,
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.movie_outlined,
          size: 36,
          color: AppColors.onSurfaceVariant.withOpacity(0.4),
        ),
      ),
    );
  }
}
