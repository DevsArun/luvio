import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/mime_types.dart';
import '../../core/utils/storage_access.dart';

import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../models/app_enums.dart';
import '../../models/video_item.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/media/video_thumbnail_image.dart';
import '../../widgets/shell/top_bar.dart';
import '../dialogs/video_options_sheet.dart';

/// Folder video list exactly per the reference "video_list" screen:
/// folder title in the top bar, Select Multiple + count toolbar with a
/// SORT BY control, and large rounded list rows (256px thumbnail, headline
/// title, icon meta chips, share/delete actions, selectable state).
class FolderVideosScreen extends StatefulWidget {
  const FolderVideosScreen({super.key, required this.folderPath});

  final String folderPath;

  @override
  State<FolderVideosScreen> createState() =>
      _FolderVideosScreenState();
}

class _FolderVideosScreenState extends State<FolderVideosScreen> {
  SortMode _sort = SortMode.dateAdded;
  bool _selectMode = false;
  final Set<String> _selected = {};

  String get _folderName {
    final parts = widget.folderPath
        .split('/')
        .where((p) => p.isNotEmpty)
        .toList();
    return parts.isEmpty ? widget.folderPath : parts.last;
  }

  List<VideoItem> _sorted(List<VideoItem> videos) {
    final list = [...videos];
    switch (_sort) {
      case SortMode.name:
        list.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case SortMode.dateAdded:
        list.sort((a, b) => b.modified.compareTo(a.modified));
      case SortMode.size:
        list.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
      case SortMode.duration:
        list.sort((a, b) => b.durationMs.compareTo(a.durationMs));
    }
    return list;
  }

  void _play(VideoItem video, List<VideoItem> queue) {
    context.read<PlayerProvider>().open(video, queue: queue);
    Navigator.of(context).pushNamed(
      Routes.player,
      arguments: PlayerScreenArgs(video: video),
    );
  }

  void _toggle(VideoItem video) {
    setState(() {
      if (!_selected.remove(video.path)) {
        _selected.add(video.path);
      }
    });
  }

  Future<void> _share(List<VideoItem> videos) async {
    if (videos.isEmpty) return;
    try {
      // A concrete MIME type makes WhatsApp / Telegram / Drive / Bluetooth
      // all appear in the share sheet. Without it many apps filter us out.
      await Share.shareXFiles(
        [
          for (final v in videos)
            XFile(v.path, mimeType: mimeTypeForPath(v.path), name: v.fileName)
        ],
        text: videos.length == 1
            ? videos.first.title
            : '${videos.length} videos from Luvio Player',
      );
    } catch (_) {
      if (!mounted) return;
      showActionResult(context, 'Could not open the share sheet');
    }
  }

  Future<void> _confirmDelete(List<VideoItem> videos) async {
    if (videos.isEmpty) return;
    final library = context.read<LibraryProvider>();
    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(videos.length == 1
                ? 'Delete video?'
                : 'Delete ${videos.length} videos?'),
            content: Text(videos.length == 1
                ? '"${videos.first.title}" will be permanently deleted from this device.'
                : 'The selected videos will be permanently deleted from this device.'),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(false),
                child: Text('Cancel'),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(dialogContext).pop(true),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white),
                child: Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    var deleted = 0;
    var blocked = 0;
    for (final video in videos) {
      if (await library.deleteVideo(video)) {
        deleted++;
      } else {
        blocked++;
      }
    }
    if (!mounted) return;
    setState(() {
      _selected.clear();
      _selectMode = false;
    });
    if (blocked > 0 && deleted == 0) {
      showStorageAccessNeeded(context, action: 'delete');
    } else if (blocked > 0) {
      showActionResult(
          context, '$deleted deleted • $blocked blocked by Android');
    } else {
      showActionResult(
          context, deleted == 1 ? 'Video deleted' : '$deleted videos deleted');
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final videos =
        _sorted(library.videosInFolder(widget.folderPath));
    final totalBytes =
        videos.fold<int>(0, (sum, v) => sum + v.sizeBytes);
    final selectedVideos = [
      for (final v in videos)
        if (_selected.contains(v.path)) v
    ];

    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLowest,
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: TopBar.height),
              // ---------------- Toolbar ----------------
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 32, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                        color: Colors.white.withOpacity(0.05)),
                  ),
                ),
                child: Row(
                  children: [
                    Material(
                      color: _selectMode
                          ? AppColors.primaryContainer
                              .withOpacity(0.2)
                          : AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(999),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => setState(() {
                          _selectMode = !_selectMode;
                          if (!_selectMode) _selected.clear();
                        }),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _selectMode
                                    ? Icons.close
                                    : Icons.checklist,
                                size: 18,
                                color: _selectMode
                                    ? AppColors.primary
                                    : AppColors.onSurfaceVariant,
                              ),
                              SizedBox(width: 8),
                              Text(
                                _selectMode
                                    ? 'Cancel'
                                    : 'Select Multiple',
                                style: AppTypography.labelLg
                                    .copyWith(
                                  color: _selectMode
                                      ? AppColors.primary
                                      : AppColors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _selectMode
                            ? '${_selected.length} selected'
                            : '${videos.length} ${videos.length == 1 ? 'Video' : 'Videos'} • ${Formatters.bytes(totalBytes)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMd.copyWith(
                            color: AppColors.onSurfaceVariant),
                      ),
                    ),
                    if (_selectMode) ...[
                      IconButton(
                        tooltip: 'Share selected',
                        onPressed: selectedVideos.isEmpty
                            ? null
                            : () => _share(selectedVideos),
                        icon: Icon(Icons.share_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete selected',
                        onPressed: selectedVideos.isEmpty
                            ? null
                            : () =>
                                _confirmDelete(selectedVideos),
                        icon: Icon(Icons.delete_outline,
                            color: AppColors.error),
                      ),
                    ] else ...[
                      Text(
                        'SORT BY',
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant
                              .withOpacity(0.6),
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8),
                      PopupMenuButton<SortMode>(
                        tooltip: 'Sort by',
                        color: AppColors.surfaceContainerHigh,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(16)),
                        initialValue: _sort,
                        onSelected: (mode) =>
                            setState(() => _sort = mode),
                        itemBuilder: (context) => [
                          for (final mode in SortMode.values)
                            PopupMenuItem(
                                value: mode,
                                child: Text(mode.label)),
                        ],
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _sort.label,
                                style: AppTypography.labelLg
                                    .copyWith(
                                        color:
                                            AppColors.primary,
                                        fontWeight:
                                            FontWeight.w600),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_downward,
                                  size: 16,
                                  color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // ---------------- List ----------------
              Expanded(
                child: videos.isEmpty
                    ? EmptyState(
                        icon: Icons.videocam_off_outlined,
                        title: 'Empty folder',
                        message:
                            'No playable videos were found in this folder.',
                      )
                    : ListView.separated(
                        padding: EdgeInsets.all(
                            MediaQuery.of(context).size.width < 600
                                ? 16
                                : 32),
                        itemCount: videos.length,
                        separatorBuilder: (_, __) =>
                            SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final video = videos[index];
                          final selected =
                              _selected.contains(video.path);
                          return _VideoRow(
                            video: video,
                            selectMode: _selectMode,
                            selected: selected,
                            onTap: () => _selectMode
                                ? _toggle(video)
                                : _play(video, videos),
                            onLongPress: () => setState(() {
                              _selectMode = true;
                              _selected.add(video.path);
                            }),
                            onShare: () => _share([video]),
                            onDelete: () =>
                                _confirmDelete([video]),
                            onMore: () => showVideoOptionsSheet(
                                context,
                                video: video),
                          );
                        },
                      ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: TopBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back,
                        color: AppColors.onSurface),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.folder_open,
                      color: AppColors.primary, size: 26),
                  SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      _folderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headlineMd,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reference list row: 256px thumbnail with duration badge and progress,
/// headline title, icon meta chips and share/delete/more actions.
class _VideoRow extends StatelessWidget {
  _VideoRow({
    required this.video,
    required this.selectMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onShare,
    required this.onDelete,
    required this.onMore,
  });

  final VideoItem video;
  final bool selectMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onShare;
  final VoidCallback onDelete;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primaryContainer.withOpacity(0.1)
          : AppColors.card,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withOpacity(0.3)
                  : Colors.white.withOpacity(0.05),
            ),
          ),
          child: Row(
            children: [
              if (selectMode) ...[
                Icon(
                  selected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: selected
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                ),
                SizedBox(width: 16),
              ],
              // Thumbnail
              SizedBox(
                width: MediaQuery.of(context).size.width < 600
                    ? 128
                    : 220,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        VideoThumbnailImage(video: video),
                        Center(
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.black
                                  .withOpacity(0.45),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white
                                      .withOpacity(0.2)),
                            ),
                            child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 26),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding:
                                EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black
                                  .withOpacity(0.7),
                              borderRadius:
                                  BorderRadius.circular(6),
                            ),
                            child: Text(
                              Formatters
                                  .duration(video.duration),
                              style: AppTypography.labelMd
                                  .copyWith(
                                      color: Colors.white),
                            ),
                          ),
                        ),
                        if (video.inProgress)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: SizedBox(
                              height: 4,
                              child: Stack(children: [
                                Container(
                                    color: Colors.black
                                        .withOpacity(0.5)),
                                FractionallySizedBox(
                                  widthFactor: video.progress
                                      .clamp(0.0, 1.0),
                                  child: Container(
                                      color: AppColors
                                          .primaryContainer),
                                ),
                              ]),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 24),
              // Title + meta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headlineMd,
                    ),
                    SizedBox(height: 12),
                    Wrap(
                      spacing: 20,
                      runSpacing: 8,
                      children: [
                        _Meta(
                          icon: Icons.high_quality_outlined,
                          text: video.resolutionBadge ??
                              video.extension.toUpperCase(),
                        ),
                        _Meta(
                          icon: Icons.folder_zip_outlined,
                          text: Formatters
                              .bytes(video.sizeBytes),
                        ),
                        _Meta(
                          icon: Icons.calendar_today_outlined,
                          text:
                              Formatters.date(video.modified),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!selectMode) ...[
                SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Share',
                      onPressed: onShare,
                      icon: Icon(Icons.share_outlined,
                          size: 20,
                          color: AppColors.onSurfaceVariant),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: onDelete,
                      icon: Icon(Icons.delete_outline,
                          size: 20, color: AppColors.error),
                    ),
                  ],
                ),
                IconButton(
                  tooltip: 'More options',
                  onPressed: onMore,
                  icon: Icon(Icons.more_vert,
                      color: AppColors.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.onSurfaceVariant),
        SizedBox(width: 6),
        Text(
          text,
          style: AppTypography.labelLg
              .copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}
