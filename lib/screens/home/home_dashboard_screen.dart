import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../models/media_folder.dart';
import '../../models/storage_volume.dart';
import '../../models/video_item.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/media/continue_watching_card.dart';
import '../../widgets/media/video_card.dart';
import '../../widgets/media/video_list_tile.dart';
import '../../widgets/shell/top_bar.dart';
import '../dialogs/video_options_sheet.dart';
import '../shell/app_shell.dart';

/// Home dashboard exactly per the reference: Continue Watching hero rail,
/// Storage & Folders bento grid and the Recently Added grid/list.
class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({
    super.key,
    required this.onSectionSelected,
  });

  final ValueChanged<AppSection> onSectionSelected;

  @override
  State<HomeDashboardScreen> createState() =>
      _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  bool _gridView = true;

  void _play(VideoItem video, List<VideoItem> queue) {
    context.read<PlayerProvider>().open(video, queue: queue);
    Navigator.of(context).pushNamed(
      Routes.player,
      arguments: PlayerScreenArgs(video: video),
    );
  }

  IconData _folderIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('movie')) return Icons.movie;
    if (n.contains('down')) return Icons.download;
    if (n.contains('series') || n.contains('tv')) return Icons.tv;
    if (n.contains('camera') || n.contains('dcim')) {
      return Icons.photo_camera;
    }
    return Icons.folder;
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final width = MediaQuery.of(context).size.width;
    final columns =
        width >= 1400 ? 4 : (width >= 1000 ? 3 : (width >= 480 ? 2 : 1));

    final continueWatching = library.continueWatching;
    final recentlyAdded = library.recentlyAdded;

    // Top folders by size for the bento grid.
    final topFolders = [...library.folders]
      ..sort((a, b) => b.totalBytes.compareTo(a.totalBytes));
    final bentoFolders = topFolders.take(3).toList();
    final removable = library.volumes
        .where((v) => v.isRemovable)
        .toList(growable: false);

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.of(context).size.width < 600
                ? 16.0
                : AppSpacing.containerPadding,
            TopBar.height + 16,
            MediaQuery.of(context).size.width < 600
                ? 16.0
                : AppSpacing.containerPadding,
            48,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 1600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (library.videos.isEmpty) ...[
                      SizedBox(height: 24),
                      EmptyState(
                        icon: Icons.video_library_outlined,
                        title: 'No videos yet',
                        message:
                            'Luvio Player hasn’t found any videos on this device. '
                            'Run a storage scan to build your library.',
                        action: FilledButton.icon(
                          onPressed: () => Navigator.of(context)
                              .pushNamed(Routes.scan),
                          icon: Icon(Icons.radar),
                          label: Text('Scan Storage'),
                        ),
                      ),
                      SizedBox(height: 48),
                    ] else ...[
                      // --- Continue Watching -----------------------------
                      if (continueWatching.isNotEmpty) ...[
                        Text('Continue Watching',
                            style: AppTypography.headlineMd),
                        SizedBox(height: 24),
                        SizedBox(
                          height: 225,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: continueWatching.length,
                            separatorBuilder: (_, __) =>
                                SizedBox(
                                    width: AppSpacing.cardGap),
                            itemBuilder: (context, index) {
                              final video =
                                  continueWatching[index];
                              return ContinueWatchingCard(
                                video: video,
                                onTap: () => _play(
                                    video, continueWatching),
                              );
                            },
                          ),
                        ),
                        SizedBox(height: 48),
                      ],
                    ],
                    // --- Storage & Folders bento -------------------------
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Storage & Folders',
                            style: AppTypography.headlineMd),
                        TextButton(
                          onPressed: () => widget
                              .onSectionSelected(AppSection.folders),
                          child: Text(
                            'Manage All',
                            style: AppTypography.labelLg
                                .copyWith(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cols =
                            constraints.maxWidth >= 1100 ? 4 : 2;
                        final cardWidth = (constraints.maxWidth -
                                (cols - 1) * AppSpacing.cardGap) /
                            cols;
                        final tints = [
                          AppColors.secondary,
                          AppColors.tertiary,
                          AppColors.primary,
                        ];
                        return Wrap(
                          spacing: AppSpacing.cardGap,
                          runSpacing: AppSpacing.cardGap,
                          children: [
                            for (var i = 0;
                                i < bentoFolders.length;
                                i++)
                              SizedBox(
                                width: cardWidth,
                                child: _FolderBentoCard(
                                  icon: _folderIcon(
                                      bentoFolders[i].name),
                                  tint: tints[i % tints.length],
                                  folder: bentoFolders[i],
                                  onTap: () => Navigator.of(context)
                                      .pushNamed(
                                    Routes.folderVideos,
                                    arguments:
                                        bentoFolders[i].path,
                                  ),
                                ),
                              ),
                            SizedBox(
                              width: cardWidth,
                              child: removable.isNotEmpty
                                  ? _VolumeBentoCard(
                                      volume: removable.first,
                                      onTap: () => widget
                                          .onSectionSelected(
                                              AppSection.folders),
                                    )
                                  : _ScanBentoCard(
                                      onTap: () =>
                                          Navigator.of(context)
                                              .pushNamed(
                                                  Routes.scan),
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: 48),
                    // --- Recently Added ----------------------------------
                    if (recentlyAdded.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Recently Added',
                              style: AppTypography.headlineMd),
                          Row(
                            children: [
                              _ViewToggle(
                                icon: Icons.grid_view_rounded,
                                active: _gridView,
                                tooltip: 'Grid view',
                                onTap: () => setState(
                                    () => _gridView = true),
                              ),
                              SizedBox(width: 8),
                              _ViewToggle(
                                icon: Icons.view_list_rounded,
                                active: !_gridView,
                                tooltip: 'List view',
                                onTap: () => setState(
                                    () => _gridView = false),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                      if (_gridView)
                        GridView.builder(
                          shrinkWrap: true,
                          physics:
                              NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisSpacing: AppSpacing.cardGap,
                            crossAxisSpacing: AppSpacing.cardGap,
                            childAspectRatio: 16 / 12.4,
                          ),
                          itemCount: recentlyAdded.length,
                          itemBuilder: (context, index) {
                            final video = recentlyAdded[index];
                            return VideoCard(
                              video: video,
                              onTap: () =>
                                  _play(video, recentlyAdded),
                              onMore: () => showVideoOptionsSheet(
                                  context,
                                  video: video),
                            );
                          },
                        )
                      else
                        Column(
                          children: [
                            for (final video in recentlyAdded)
                              Padding(
                                padding: EdgeInsets.only(
                                    bottom: 12),
                                child: VideoListTile(
                                  video: video,
                                  onTap: () => _play(
                                      video, recentlyAdded),
                                  onMore: () =>
                                      showVideoOptionsSheet(
                                          context,
                                          video: video),
                                ),
                              ),
                          ],
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

/// Bento folder card — 180px tall rounded-3xl surface-container card with a
/// 56px tinted icon tile, title and "N Items • Size" meta line.
class _FolderBentoCard extends StatelessWidget {
  _FolderBentoCard({
    required this.icon,
    required this.tint,
    required this.folder,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final MediaFolder folder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppColors.surfaceContainerHighest,
        child: Container(
          height: 180,
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border:
                Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: tint.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: tint, size: 28),
              ),
              Spacer(),
              Text(
                folder.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyLg
                    .copyWith(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 4),
              Text(
                '${folder.videoCount} ${folder.videoCount == 1 ? 'Item' : 'Items'} • ${Formatters.bytes(folder.totalBytes)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelMd.copyWith(
                    color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// SD-card style bento card with a capacity meter and "% Full" label.
class _VolumeBentoCard extends StatelessWidget {
  _VolumeBentoCard({required this.volume, required this.onTap});

  final StorageVolume volume;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fraction = volume.usedFraction.clamp(0.0, 1.0);
    final critical = fraction >= 0.8;
    final meterColor =
        critical ? AppColors.error : AppColors.primaryContainer;
    return Material(
      color: AppColors.surfaceVariant.withOpacity(0.5),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 180,
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: AppColors.outline.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.1)),
                ),
                child: Icon(Icons.sd_card,
                    color: AppColors.onSurfaceVariant, size: 28),
              ),
              Spacer(),
              Text(
                volume.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyLg
                    .copyWith(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 4,
                        backgroundColor:
                            Colors.black.withOpacity(0.4),
                        color: meterColor,
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '${(fraction * 100).round()}% Full',
                    style: AppTypography.labelMd.copyWith(
                        color: critical
                            ? AppColors.error
                            : AppColors.onSurfaceVariant),
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

/// Fallback bento card that launches a storage scan.
class _ScanBentoCard extends StatelessWidget {
  _ScanBentoCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceVariant.withOpacity(0.5),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 180,
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: AppColors.outline.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.1)),
                ),
                child: Icon(Icons.radar,
                    color: AppColors.primary, size: 28),
              ),
              Spacer(),
              Text(
                'Scan Storage',
                style: AppTypography.bodyLg
                    .copyWith(fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 4),
              Text(
                'Find new videos on this device',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelMd.copyWith(
                    color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 40px circular grid/list toggle from the reference header.
class _ViewToggle extends StatelessWidget {
  _ViewToggle({
    required this.icon,
    required this.active,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? AppColors.surfaceContainer
            : Colors.transparent,
        shape: CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 20,
              color: active
                  ? AppColors.primary
                  : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
