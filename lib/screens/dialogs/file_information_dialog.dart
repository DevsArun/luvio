import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/mime_types.dart';
import '../../core/utils/storage_access.dart';

import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../models/video_item.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/media/video_thumbnail_image.dart';

/// File Information modal exactly per the reference: a wide glass panel
/// with a thumbnail + actions column on the left (Open Folder, Share,
/// Rename, Delete File) and a bento grid of stream/data cards on the right.
Future<void> showFileInformationDialog(
  BuildContext context, {
  required VideoItem video,
  VoidCallback? onPlay,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (_) => FileInformationDialog(video: video, onPlay: onPlay),
  );
}

class FileInformationDialog extends StatefulWidget {
  const FileInformationDialog({
    super.key,
    required this.video,
    this.onPlay,
  });

  final VideoItem video;
  final VoidCallback? onPlay;

  @override
  State<FileInformationDialog> createState() =>
      _FileInformationDialogState();
}

class _FileInformationDialogState extends State<FileInformationDialog> {
  bool _probing = false;

  VideoItem get video => widget.video;

  @override
  void initState() {
    super.initState();
    if (!widget.video.probed) {
      _probing = true;
      context
          .read<LibraryProvider>()
          .probeNow(widget.video)
          .whenComplete(() {
        if (mounted) setState(() => _probing = false);
      });
    }
  }

  void _play() {
    Navigator.of(context).pop();
    if (widget.onPlay != null) {
      widget.onPlay!.call();
      return;
    }
    final player = context.read<PlayerProvider>();
    player.open(video, queue: [video]);
    Navigator.of(context).pushNamed(
      Routes.player,
      arguments: PlayerScreenArgs(video: video),
    );
  }

  void _openFolder() {
    Navigator.of(context).pop();
    Navigator.of(context)
        .pushNamed(Routes.folderVideos, arguments: video.folderPath);
  }

  Future<void> _share() async {
    try {
      await Share.shareXFiles(
        [
          XFile(video.path,
              mimeType: mimeTypeForPath(video.path), name: video.fileName)
        ],
        text: video.title,
      );
    } catch (_) {
      if (!mounted) return;
      showActionResult(context, 'Could not open the share sheet');
    }
  }

  Future<void> _rename() async {
    final library = context.read<LibraryProvider>();
    final controller = TextEditingController(text: video.title);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Rename video'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration:
              InputDecoration(labelText: 'File name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext)
                .pop(controller.text.trim()),
            child: Text('Rename'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == video.title) {
      return;
    }
    final ok = await library.renameVideo(video, newName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok
            ? 'Renamed to "$newName"'
            : 'Could not rename this file')));
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final library = context.read<LibraryProvider>();
    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('Delete video?'),
            content: Text(
                '"${video.title}" will be permanently deleted from this device.'),
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
    if (!ok || !mounted) return;
    final deleted = await library.deleteVideo(video);
    if (!mounted) return;
    if (!deleted) {
      showStorageAccessNeeded(context, action: 'delete');
      return;
    }
    Navigator.of(context).pop();
    showActionResult(context, 'Video deleted');
  }

  String get _bitrateLine {
    if (video.durationMs <= 0) return 'Bitrate unavailable';
    final mbps =
        video.sizeBytes * 8 / (video.durationMs / 1000) / 1000000;
    return '${mbps.toStringAsFixed(1)} Mbps average';
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxWidth: 1000, maxHeight: 680),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow.withOpacity(0.98),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: AppColors.ambientShadow,
          ),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 5, child: _leftPane()),
                    Container(
                        width: 1,
                        color: Colors.white.withOpacity(0.05)),
                    Expanded(flex: 7, child: _rightPane()),
                  ],
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: 220, child: _thumbnail()),
                      _rightPane(scroll: false),
                      _actions(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  // ---------------- Left: thumbnail + actions ----------------

  Widget _leftPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _thumbnail()),
        _actions(),
      ],
    );
  }

  Widget _thumbnail() {
    return Stack(
      fit: StackFit.expand,
      children: [
        VideoThumbnailImage(video: video),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.6),
              ],
            ),
          ),
        ),
        Center(
          child: Material(
            color: Colors.black.withOpacity(0.4),
            shape: CircleBorder(
                side: BorderSide(
                    color: Colors.white.withOpacity(0.3))),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _play,
              child: SizedBox(
                width: 80,
                height: 80,
                child: Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 44),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          bottom: 16,
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              Formatters.duration(video.duration),
              style: AppTypography.labelMd
                  .copyWith(color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actions() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withOpacity(0.5),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: _openFolder,
            icon: Icon(Icons.open_in_new, size: 18),
            label: Text('Open Folder'),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _share,
                  icon: Icon(Icons.share_outlined, size: 18),
                  label: Text('Share'),
                  style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                          horizontal: 12)),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _rename,
                  icon: Icon(Icons.edit_outlined, size: 18),
                  label: Text('Rename'),
                  style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                          horizontal: 12)),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          TextButton.icon(
            onPressed: _delete,
            icon: Icon(Icons.delete_outline, size: 18),
            label: Text('Delete File'),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.error),
          ),
        ],
      ),
    );
  }

  // ---------------- Right: header + bento data cards ----------------

  Widget _rightPane({bool scroll = true}) {
    final content = Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headlineLg
                          .copyWith(fontSize: 26),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.folder_outlined,
                            size: 16,
                            color: AppColors.onSurfaceVariant),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            video.folderPath,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelLg
                                .copyWith(
                                    color: AppColors
                                        .onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Material(
                color: AppColors.surfaceContainer,
                shape: CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Icon(Icons.close,
                        size: 20,
                        color: AppColors.onSurfaceVariant),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 24),
          if (_probing)
            Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Analyzing file…',
                      style: AppTypography.labelLg.copyWith(
                          color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoCols = constraints.maxWidth >= 440;
              final w = twoCols
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: w,
                    child: _DataCard(
                      label: 'VIDEO STREAM',
                      icon: Icons.four_k_outlined,
                      hero: video.probed && video.width > 0
                          ? '${video.width} × ${video.height}'
                          : 'Resolution pending',
                      accent:
                          '${video.containerBadge} • ${video.resolutionBadge ?? 'SD'}',
                      accentColor: AppColors.primary,
                      detail: _bitrateLine,
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: _DataCard(
                      label: 'AUDIO STREAM',
                      icon: Icons.surround_sound_outlined,
                      hero: 'Auto-detected',
                      accent: 'Tracks selectable in player',
                      accentColor: AppColors.secondary,
                      detail: 'Switch audio from player controls',
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: _DataCard(
                      label: 'SUBTITLES',
                      icon: Icons.subtitles_outlined,
                      hero: 'External',
                      accent: 'Sidecar .srt / .ass supported',
                      accentColor: AppColors.tertiary,
                      detail: 'Load from the player subtitle menu',
                    ),
                  ),
                  SizedBox(
                    width: w,
                    child: _DataCard(
                      label: 'FILE DETAILS',
                      icon: Icons.storage_outlined,
                      hero: Formatters.bytes(video.sizeBytes),
                      accent:
                          'Modified: ${Formatters.date(video.modified)}',
                      accentColor: AppColors.onSurfaceVariant,
                      detail:
                          'Container: ${video.extension.toUpperCase()}',
                    ),
                  ),
                ],
              );
            },
          ),
          SizedBox(height: 16),
          // Full-width storage row card
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        AppColors.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.dns_outlined,
                      size: 20, color: AppColors.primary),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text('Local Storage',
                          style: AppTypography.labelLg.copyWith(
                              fontWeight: FontWeight.w600)),
                      Text(
                        video.folderPath,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelMd.copyWith(
                            color:
                                AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('Scanned',
                      style: AppTypography.labelMd.copyWith(
                          color: AppColors.onSurface)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!scroll) return content;
    return SingleChildScrollView(child: content);
  }
}

class _DataCard extends StatelessWidget {
  _DataCard({
    required this.label,
    required this.icon,
    required this.hero,
    required this.accent,
    required this.accentColor,
    required this.detail,
  });

  final String label;
  final IconData icon;
  final String hero;
  final String accent;
  final Color accentColor;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.onSurfaceVariant
                        .withOpacity(0.7),
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(icon,
                  size: 20, color: AppColors.onSurfaceVariant),
            ],
          ),
          SizedBox(height: 12),
          Text(hero,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.headlineMd
                  .copyWith(fontSize: 20)),
          SizedBox(height: 4),
          Text(accent,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelLg
                  .copyWith(color: accentColor)),
          SizedBox(height: 2),
          Text(detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant
                      .withOpacity(0.7))),
        ],
      ),
    );
  }
}
