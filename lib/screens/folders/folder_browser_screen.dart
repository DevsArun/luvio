import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../models/storage_volume.dart';
import '../../providers/library_provider.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/media/folder_card.dart';
import '../../widgets/shell/top_bar.dart';

/// Storage browser: device volume cards with capacity meters plus every
/// folder that contains videos.
class FolderBrowserScreen extends StatelessWidget {
  const FolderBrowserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final wide = MediaQuery.of(context).size.width >= 1280;
    final folders = library.folders;

    final folderGrid = folders.isEmpty
        ? EmptyState(
            icon: Icons.folder_off_outlined,
            title: 'No folders with videos',
            message:
                'Run a storage scan and Luvio Player will organize every '
                'folder that contains video files.',
            action: FilledButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed(Routes.scan),
              icon: Icon(Icons.radar),
              label: Text('Scan Storage'),
            ),
          )
        : LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  (constraints.maxWidth / 280).floor().clamp(1, 5);
              final cardWidth = (constraints.maxWidth -
                      (columns - 1) * 16) /
                  columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final folder in folders)
                    SizedBox(
                      width: cardWidth,
                      child: FolderCard(
                        name: folder.name,
                        subtitle:
                            '${folder.videoCount} ${folder.videoCount == 1 ? 'video' : 'videos'} • ${Formatters.bytes(folder.totalBytes)}',
                        onTap: () =>
                            Navigator.of(context).pushNamed(
                          Routes.folderVideos,
                          arguments: folder.path,
                        ),
                      ),
                    ),
                ],
              );
            },
          );

    final devicePanel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MicroHeader('DEVICE STORAGE'),
        SizedBox(height: 12),
        if (library.volumes.isEmpty)
          Text(
            'No storage volumes detected yet.',
            style: AppTypography.labelMd.copyWith(
                color:
                    AppColors.onSurfaceVariant.withOpacity(0.6)),
          )
        else
          for (final volume in library.volumes)
            Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: _DeviceCard(
                volume: volume,
                videoCount: library.itemCountUnder(volume.path),
              ),
            ),
      ],
    );

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.of(context).size.width < 600
                ? 16.0
                : AppSpacing.containerPadding,
            TopBar.height + 24,
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
                    Text(
                      'Storage / Folders',
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.primary,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text('Folders',
                        style: AppTypography.displayLg),
                    SizedBox(height: 8),
                    Text(
                      '${folders.length} ${folders.length == 1 ? 'folder' : 'folders'} with videos',
                      style: AppTypography.bodyLg.copyWith(
                          color: AppColors.onSurfaceVariant
                              .withOpacity(0.7)),
                    ),
                    SizedBox(height: 32),
                    if (wide)
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                              width: 320, child: devicePanel),
                          SizedBox(
                              width: AppSpacing.gutter),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                SectionHeader(
                                    title: 'All Folders'),
                                SizedBox(height: 16),
                                folderGrid,
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      devicePanel,
                      SizedBox(height: 24),
                      SectionHeader(title: 'All Folders'),
                      SizedBox(height: 16),
                      folderGrid,
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

class _DeviceCard extends StatelessWidget {
  _DeviceCard({
    required this.volume,
    required this.videoCount,
  });

  final StorageVolume volume;
  final int videoCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.card,
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (volume.isRemovable
                          ? AppColors.tertiary
                          : AppColors.primaryContainer)
                      .withOpacity(0.18),
                  borderRadius: AppRadius.panel,
                ),
                child: Icon(
                  volume.isRemovable
                      ? Icons.sd_card_outlined
                      : Icons.smartphone,
                  color: volume.isRemovable
                      ? AppColors.tertiary
                      : AppColors.primary,
                  size: 22,
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(volume.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyLg.copyWith(
                            fontWeight: FontWeight.w600)),
                    Text(
                      '$videoCount ${videoCount == 1 ? 'video' : 'videos'}',
                      style: AppTypography.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant
                              .withOpacity(0.6)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: volume.usedFraction.clamp(0.0, 1.0),
              minHeight: 5,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '${Formatters.bytes(volume.freeBytes)} free of ${Formatters.bytes(volume.totalBytes)}',
            style: AppTypography.labelMd.copyWith(
                color:
                    AppColors.onSurfaceVariant.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }
}
