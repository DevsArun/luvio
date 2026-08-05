import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/playlist.dart';
import '../../models/video_item.dart';
import '../../providers/playlist_provider.dart';

/// Icon choices offered when creating a playlist.
final Map<String, IconData> kPlaylistIcons = {
  'playlist_play': Icons.playlist_play,
  'favorite': Icons.favorite,
  'movie': Icons.movie_outlined,
  'music': Icons.music_note,
  'star': Icons.star_outline,
  'bolt': Icons.bolt,
  'family': Icons.family_restroom,
  'school': Icons.school_outlined,
};

IconData playlistIcon(String name) =>
    kPlaylistIcons[name] ?? Icons.playlist_play;

/// Create Playlist dialog: name field + icon picker. Optionally adds an
/// initial video to the new playlist.
Future<Playlist?> showCreatePlaylistDialog(
  BuildContext context, {
  VideoItem? initialVideo,
}) {
  final controller = TextEditingController();
  var selectedIcon = 'playlist_play';

  return showDialog<Playlist>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        void submit() {
          final name = controller.text.trim();
          if (name.isEmpty) return;
          final playlists = context.read<PlaylistProvider>();
          final playlist =
              playlists.createPlaylist(name, iconName: selectedIcon);
          if (initialVideo != null) {
            playlists.addToPlaylist(playlist, initialVideo.path);
          }
          Navigator.of(context).pop(playlist);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Playlist “$name” created')),
          );
        }

        return AlertDialog(
          title: Text('Create Playlist'),
          shape: RoundedRectangleBorder(
              borderRadius: AppRadius.container),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  style: AppTypography.bodyMd,
                  decoration: InputDecoration(
                      hintText: 'Playlist name'),
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => submit(),
                ),
                SizedBox(height: 20),
                Text(
                  'CHOOSE AN ICON',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.primary,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final entry in kPlaylistIcons.entries)
                      if (entry.key != 'favorite')
                        Material(
                          color: selectedIcon == entry.key
                              ? AppColors.primaryContainer
                              : AppColors.surfaceContainerHigh,
                          borderRadius: AppRadius.panel,
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => setState(
                                () => selectedIcon = entry.key),
                            child: SizedBox(
                              width: 52,
                              height: 52,
                              child: Icon(
                                entry.value,
                                color: selectedIcon == entry.key
                                    ? AppColors.onPrimaryContainer
                                    : AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            FilledButton(
              onPressed: submit,
              child: Text('Create'),
            ),
          ],
        );
      },
    ),
  );
}

/// "Add to playlist" bottom sheet — tap a playlist to toggle membership.
Future<void> showAddToPlaylistSheet(
  BuildContext context, {
  required VideoItem video,
}) {
  return showModalBottomSheet<void>(
    context: context,
    constraints: BoxConstraints(maxWidth: 560),
    builder: (sheetContext) => Consumer<PlaylistProvider>(
      builder: (context, playlists, _) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(24, 4, 24, 12),
              child: Text('Add to playlist',
                  style: AppTypography.headlineMd),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding:
                    EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final playlist in playlists.playlists)
                    ListTile(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: playlist.isFavorites
                              ? AppColors.errorContainer
                                  .withOpacity(0.35)
                              : AppColors.primaryContainer
                                  .withOpacity(0.18),
                          borderRadius: AppRadius.panel,
                        ),
                        child: Icon(
                          playlistIcon(playlist.iconName),
                          color: playlist.isFavorites
                              ? AppColors.error
                              : AppColors.primary,
                          size: 22,
                        ),
                      ),
                      title: Text(playlist.name,
                          style: AppTypography.bodyMd),
                      subtitle: Text(
                        '${playlist.itemCount} ${playlist.itemCount == 1 ? 'video' : 'videos'}',
                        style: AppTypography.labelMd.copyWith(
                            color: AppColors.onSurfaceVariant
                                .withOpacity(0.6)),
                      ),
                      trailing: playlists.contains(
                              playlist, video.path)
                          ? Icon(Icons.check_circle,
                              color: AppColors.primary)
                          : Icon(
                              Icons.add_circle_outline,
                              color: AppColors.onSurfaceVariant),
                      onTap: () {
                        if (playlists.contains(
                            playlist, video.path)) {
                          playlists.removeFromPlaylist(
                              playlist, video.path);
                        } else {
                          playlists.addToPlaylist(
                              playlist, video.path);
                        }
                      },
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(24),
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  await showCreatePlaylistDialog(context,
                      initialVideo: video);
                },
                icon: Icon(Icons.add, size: 20),
                label: Text('New Playlist'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
