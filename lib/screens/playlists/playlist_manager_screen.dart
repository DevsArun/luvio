import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../models/playlist.dart';
import '../../providers/playlist_provider.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/shell/top_bar.dart';
import '../dialogs/playlist_dialogs.dart';

/// Playlist manager: favorites card first, then every custom playlist,
/// plus a New Playlist action.
class PlaylistManagerScreen extends StatelessWidget {
  const PlaylistManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final playlists = context.watch<PlaylistProvider>();

    // Favorites first, then customs in creation order.
    final ordered = [
      ...playlists.playlists.where((p) => p.isFavorites),
      ...playlists.playlists.where((p) => !p.isFavorites),
    ];

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.containerPadding,
            TopBar.height + 24,
            AppSpacing.containerPadding,
            48,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 1600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MicroHeader('COLLECTIONS'),
                    SizedBox(height: 8),
                    Text('Playlists',
                        style: AppTypography.displayLg),
                    SizedBox(height: 8),
                    Text(
                      '${ordered.length} ${ordered.length == 1 ? 'playlist' : 'playlists'}',
                      style: AppTypography.bodyLg.copyWith(
                          color: AppColors.onSurfaceVariant
                              .withOpacity(0.7)),
                    ),
                    SizedBox(height: 32),
                    SectionHeader(
                      title: 'Your Playlists',
                      trailing: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: AppRadius.pill,
                          boxShadow: AppColors.primaryGlow,
                        ),
                        child: FilledButton.icon(
                          onPressed: () =>
                              showCreatePlaylistDialog(context),
                          icon: Icon(Icons.add, size: 20),
                          label: Text('New Playlist'),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = (constraints.maxWidth / 320)
                            .floor()
                            .clamp(1, 4);
                        final cardWidth =
                            (constraints.maxWidth -
                                    (columns - 1) *
                                        AppSpacing.cardGap) /
                                columns;
                        return Wrap(
                          spacing: AppSpacing.cardGap,
                          runSpacing: AppSpacing.cardGap,
                          children: [
                            for (final playlist in ordered)
                              SizedBox(
                                width: cardWidth,
                                child: _PlaylistCard(
                                    playlist: playlist),
                              ),
                          ],
                        );
                      },
                    ),
                    if (ordered.length <= 1) ...[
                      SizedBox(height: 40),
                      Center(
                        child: Column(
                          children: [
                            Icon(Icons.playlist_add,
                                size: 48,
                                color: AppColors.onSurfaceVariant
                                    .withOpacity(0.4)),
                            SizedBox(height: 12),
                            Text(
                              'Create playlists to group movies, series and lectures.',
                              style: AppTypography.bodyMd
                                  .copyWith(
                                      color: AppColors
                                          .onSurfaceVariant
                                          .withOpacity(0.6)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        Positioned(
            top: 0, left: 0, right: 0, child: TopBar()),
      ],
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  _PlaylistCard({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final accent = playlist.isFavorites
        ? AppColors.error
        : AppColors.primaryContainer;

    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: AppRadius.card,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(
          Routes.playlistDetail,
          arguments: playlist.id,
        ),
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: AppRadius.card,
            border:
                Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.18),
                  borderRadius: AppRadius.panel,
                ),
                child: Icon(
                  playlist.isFavorites
                      ? Icons.favorite
                      : playlistIcon(playlist.iconName),
                  color: playlist.isFavorites
                      ? AppColors.error
                      : AppColors.primary,
                  size: 26,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyLg.copyWith(
                          fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${playlist.itemCount} ${playlist.itemCount == 1 ? 'video' : 'videos'}',
                      style: AppTypography.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant
                              .withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: AppColors.outline),
            ],
          ),
        ),
      ),
    );
  }
}
