import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/mime_types.dart';
import '../../core/utils/storage_access.dart';
import '../../models/video_item.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/vault_provider.dart';
import '../../widgets/media/video_thumbnail_image.dart';
import 'confirm_dialogs.dart';
import 'file_information_dialog.dart';
import 'playlist_dialogs.dart';

/// Contextual bottom sheet with every per-video action: play, playlist,
/// favorite, share, rename, info, vault hide/restore and delete.
Future<void> showVideoOptionsSheet(
  BuildContext context, {
  required VideoItem video,
  bool inVault = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    constraints: BoxConstraints(maxWidth: 600),
    builder: (sheetContext) {
      final library = context.read<LibraryProvider>();
      final playlists = context.read<PlaylistProvider>();
      final vault = context.read<VaultProvider>();
      final player = context.read<PlayerProvider>();

      void play() {
        Navigator.of(sheetContext).pop();
        player.open(video,
            queue: inVault ? library.vaultVideos : library.videos);
        Navigator.of(context).pushNamed(
          Routes.player,
          arguments: PlayerScreenArgs(video: video),
        );
      }

      return SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Header ---------------------------------------------
              Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: AppRadius.panel,
                      child: SizedBox(
                        width: 112,
                        height: 63,
                        child: VideoThumbnailImage(video: video),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            video.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyLg.copyWith(
                                fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${Formatters.bytes(video.sizeBytes)} • ${video.folderName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelMd.copyWith(
                                color: AppColors.onSurfaceVariant
                                    .withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1),
              // --- Actions --------------------------------------------
              ListTile(
                leading: Icon(Icons.play_arrow_rounded,
                    color: AppColors.primary),
                title: Text('Play Now'),
                onTap: play,
              ),
              ListTile(
                leading: Icon(Icons.playlist_add,
                    color: AppColors.onSurfaceVariant),
                title: Text('Add to Playlist'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showAddToPlaylistSheet(context, video: video);
                },
              ),
              Consumer<PlaylistProvider>(
                builder: (context, playlistsWatch, _) {
                  final fav = playlistsWatch.isFavorite(video.path);
                  return ListTile(
                    leading: Icon(
                      fav ? Icons.favorite : Icons.favorite_border,
                      color: fav
                          ? AppColors.error
                          : AppColors.onSurfaceVariant,
                    ),
                    title: Text(fav
                        ? 'Remove from Favorites'
                        : 'Add to Favorites'),
                    onTap: () =>
                        playlistsWatch.toggleFavorite(video.path),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.share_outlined,
                    color: AppColors.onSurfaceVariant),
                title: Text('Share'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  try {
                    // Real MIME type => WhatsApp, Telegram, Gmail, Drive,
                    // Bluetooth and Nearby Share all show up in the sheet.
                    await Share.shareXFiles(
                      [
                        XFile(video.path,
                            mimeType: mimeTypeForPath(video.path),
                            name: video.fileName)
                      ],
                      text: video.title,
                    );
                  } catch (_) {
                    if (!context.mounted) return;
                    showActionResult(
                        context, 'Could not open the share sheet');
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.drive_file_rename_outline,
                    color: AppColors.onSurfaceVariant),
                title: Text('Rename'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final newName = await showRenameDialog(context,
                      currentFileName: video.fileName);
                  if (newName == null || newName == video.fileName) {
                    return;
                  }
                  final renamed =
                      await library.renameVideo(video, newName);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(renamed
                          ? 'Renamed to “$newName”'
                          : 'Could not rename file'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(Icons.info_outline,
                    color: AppColors.onSurfaceVariant),
                title: Text('File Information'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showFileInformationDialog(context,
                      video: video, onPlay: () {
                    player.open(video,
                        queue: inVault
                            ? library.vaultVideos
                            : library.videos);
                    Navigator.of(context).pushNamed(
                      Routes.player,
                      arguments: PlayerScreenArgs(video: video),
                    );
                  });
                },
              ),
              Divider(height: 1),
              if (inVault)
                ListTile(
                  leading: Icon(Icons.lock_open,
                      color: AppColors.tertiary),
                  title: Text('Restore from Vault'),
                  subtitle: Text(
                    'Make this video visible in your library again',
                    style: AppTypography.labelMd.copyWith(
                        color: AppColors.onSurfaceVariant
                            .withOpacity(0.6)),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    vault.restoreVideo(video.path);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('Video restored to library')),
                    );
                  },
                )
              else
                ListTile(
                  leading: Icon(Icons.lock_outline,
                      color: AppColors.tertiary),
                  title: Text('Hide in Private Vault'),
                  subtitle: Text(
                    'Only visible after PIN or fingerprint unlock',
                    style: AppTypography.labelMd.copyWith(
                        color: AppColors.onSurfaceVariant
                            .withOpacity(0.6)),
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    if (!vault.hasPin) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Set up a vault PIN first — open Private Vault to get started'),
                        ),
                      );
                      return;
                    }
                    vault.hideVideo(video.path);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('Video moved to Private Vault')),
                    );
                  },
                ),
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: AppColors.error),
                title: Text('Delete',
                    style: TextStyle(color: AppColors.error)),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final confirmed = await showDeleteConfirmDialog(
                      context,
                      title: video.title);
                  if (!confirmed || !context.mounted) return;
                  final deleted = await library.deleteVideo(video);
                  if (!context.mounted) return;
                  if (!deleted) {
                    showStorageAccessNeeded(context, action: 'delete');
                    return;
                  }
                  playlists.purgePath(video.path);
                  if (!context.mounted) return;
                  showActionResult(context, 'Video deleted');
                },
              ),
              SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}
