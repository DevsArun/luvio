import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../models/video_item.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../widgets/common/circle_icon_button.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/media/video_thumbnail_image.dart';
import '../dialogs/confirm_dialogs.dart';
import '../dialogs/playlist_dialogs.dart';

/// Playlist detail: reorderable queue with Play All, rename and delete.
class PlaylistDetailScreen extends StatelessWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context) {
    final playlists = context.watch<PlaylistProvider>();
    final library = context.watch<LibraryProvider>();
    final playlist = playlists.byId(playlistId);

    if (playlist == null) {
      // Deleted while open — bounce back gracefully.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).maybePop();
      });
      return Scaffold(body: SizedBox.shrink());
    }

    // Resolve stored paths to live library entries; drop missing files.
    final videos = playlist.videoPaths
        .map(library.byPath)
        .whereType<VideoItem>()
        .toList();

    void play(VideoItem video) {
      context.read<PlayerProvider>().open(video, queue: videos);
      Navigator.of(context).pushNamed(
        Routes.player,
        arguments: PlayerScreenArgs(video: video),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Header ---------------------------------------------------
            Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.containerPadding,
                  20,
                  AppSpacing.containerPadding,
                  16),
              child: Row(
                children: [
                  CircleIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  SizedBox(width: 20),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: (playlist.isFavorites
                              ? AppColors.error
                              : AppColors.primaryContainer)
                          .withOpacity(0.18),
                      borderRadius: AppRadius.panel,
                    ),
                    child: Icon(
                      playlist.isFavorites
                          ? Icons.favorite
                          : playlistIcon(playlist.iconName),
                      color: playlist.isFavorites
                          ? AppColors.error
                          : AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(playlist.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.headlineLg),
                        SizedBox(height: 4),
                        Text(
                          '${videos.length} ${videos.length == 1 ? 'video' : 'videos'}',
                          style: AppTypography.labelMd.copyWith(
                              color: AppColors.onSurfaceVariant
                                  .withOpacity(0.7)),
                        ),
                      ],
                    ),
                  ),
                  if (videos.isNotEmpty) ...[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: AppRadius.pill,
                        boxShadow: AppColors.primaryGlow,
                      ),
                      child: FilledButton.icon(
                        onPressed: () => play(videos.first),
                        icon: Icon(
                            Icons.play_arrow_rounded),
                        label: Text('Play All'),
                      ),
                    ),
                    SizedBox(width: 12),
                  ],
                  if (!playlist.isFavorites)
                    PopupMenuButton<String>(
                      tooltip: 'Playlist options',
                      onSelected: (action) async {
                        switch (action) {
                          case 'rename':
                            final name = await showRenameDialog(
                              context,
                              currentFileName: playlist.name,
                            );
                            if (name != null &&
                                name.trim().isNotEmpty) {
                              playlists.renamePlaylist(
                                  playlist, name.trim());
                            }
                          case 'delete':
                            final confirmed =
                                await showDeleteConfirmDialog(
                                    context,
                                    title: playlist.name);
                            if (confirmed &&
                                context.mounted) {
                              playlists
                                  .deletePlaylist(playlist);
                              Navigator.of(context).pop();
                            }
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'rename',
                          child: Text('Rename playlist'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete playlist',
                              style: TextStyle(
                                  color: AppColors.error)),
                        ),
                      ],
                      child: CircleIconButton(
                        icon: Icons.more_vert,
                        onPressed: null,
                      ),
                    ),
                ],
              ),
            ),
            // --- Body -----------------------------------------------------
            Expanded(
              child: videos.isEmpty
                  ? EmptyState(
                      icon: playlist.isFavorites
                          ? Icons.favorite_border
                          : Icons.playlist_add,
                      title: playlist.isFavorites
                          ? 'No favorites yet'
                          : 'This playlist is empty',
                      message: playlist.isFavorites
                          ? 'Tap the heart on any video to keep it here for quick access.'
                          : 'Add videos from any video’s options menu → “Add to Playlist”.',
                    )
                  : ReorderableListView.builder(
                      padding: EdgeInsets.fromLTRB(
                          AppSpacing.containerPadding,
                          0,
                          AppSpacing.containerPadding,
                          48),
                      itemCount: videos.length,
                      onReorder: (oldIndex, newIndex) =>
                          playlists.reorder(
                              playlist, oldIndex, newIndex),
                      itemBuilder: (context, index) {
                        final video = videos[index];
                        return Padding(
                          key: ValueKey(video.path),
                          padding:
                              EdgeInsets.only(bottom: 12),
                          child: Material(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: AppRadius.card,
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => play(video),
                              child: Padding(
                                padding:
                                    EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    ReorderableDragStartListener(
                                      index: index,
                                      child: Padding(
                                        padding:
                                            EdgeInsets.all(8),
                                        child: Icon(
                                            Icons.drag_handle,
                                            color: AppColors
                                                .outline),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    ClipRRect(
                                      borderRadius:
                                          AppRadius.panel,
                                      child: SizedBox(
                                        width: 112,
                                        height: 63,
                                        child:
                                            VideoThumbnailImage(
                                                video: video),
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: [
                                          Text(
                                            video.title,
                                            maxLines: 1,
                                            overflow:
                                                TextOverflow
                                                    .ellipsis,
                                            style: AppTypography
                                                .bodyLg
                                                .copyWith(
                                                    fontWeight:
                                                        FontWeight
                                                            .w600),
                                          ),
                                          SizedBox(
                                              height: 4),
                                          Text(
                                            video.durationMs > 0
                                                ? '${Formatters.duration(video.duration)} • ${Formatters.bytes(video.sizeBytes)}'
                                                : Formatters
                                                    .bytes(video
                                                        .sizeBytes),
                                            style: AppTypography
                                                .labelMd
                                                .copyWith(
                                              color: AppColors
                                                  .onSurfaceVariant
                                                  .withOpacity(
                                                      0.6),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => playlists
                                          .removeFromPlaylist(
                                              playlist,
                                              video.path),
                                      tooltip:
                                          'Remove from playlist',
                                      icon: Icon(
                                          Icons
                                              .remove_circle_outline,
                                          color: AppColors
                                              .onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
