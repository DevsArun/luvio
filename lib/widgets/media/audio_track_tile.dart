import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../models/audio_track.dart';

/// A single audio track row: album-art (or note glyph) thumbnail, title +
/// artist, duration and an optional trailing control.
class AudioTrackTile extends StatelessWidget {
  const AudioTrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.onMore,
    this.isPlaying = false,
    this.trailing,
  });

  final AudioTrack track;
  final VoidCallback onTap;
  final VoidCallback? onMore;
  final bool isPlaying;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPlaying
          ? AppColors.primaryContainer.withOpacity(0.16)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: Colors.white.withOpacity(0.04),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _Artwork(track: track, isPlaying: isPlaying),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMd.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isPlaying
                            ? AppColors.primary
                            : AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${track.artist} • ${track.album}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelMd
                          .copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                track.probed ? Formatters.duration(track.duration) : '–',
                style: AppTypography.labelMd
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 4),
                trailing!,
              ] else if (onMore != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onMore,
                  icon: const Icon(Icons.more_vert),
                  color: AppColors.onSurfaceVariant,
                  tooltip: 'More options',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.track, required this.isPlaying});

  final AudioTrack track;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        gradient: track.hasCoverArt
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryContainer.withOpacity(0.35),
                  AppColors.accentPurple.withOpacity(0.35),
                ],
              ),
      ),
      clipBehavior: Clip.antiAlias,
      child: track.hasCoverArt
          ? Image.file(
              File(track.coverArtPath!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _glyph(),
            )
          : _glyph(),
    );
  }

  Widget _glyph() => Center(
        child: Icon(
          isPlaying ? Icons.graphic_eq : Icons.music_note,
          color: isPlaying ? AppColors.primary : AppColors.onSurfaceVariant,
          size: 24,
        ),
      );
}
