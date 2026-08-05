import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../models/app_enums.dart';
import '../../models/audio_track.dart';
import '../../providers/audio_player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../widgets/common/circle_icon_button.dart';
import '../../widgets/common/empty_state.dart';

/// Full-screen "Now Playing" experience for the audio engine.
class AudioPlayerScreen extends StatelessWidget {
  const AudioPlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioPlayerProvider>();
    final track = audio.current;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32),
          tooltip: 'Minimize',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Now Playing',
            style: AppTypography.labelLg
                .copyWith(color: AppColors.onSurfaceVariant)),
        centerTitle: true,
        actions: [
          if (track != null)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Track info',
              onPressed: () => _showMetadata(context, track),
            ),
        ],
      ),
      body: track == null
          ? const EmptyState(
              icon: Icons.music_off,
              title: 'Nothing playing',
              message: 'Pick a track from your audio library to start.',
            )
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final art = _Artwork(track: track);
                  final controls = _Controls(audio: audio, track: track);
                  if (constraints.maxWidth >= 900) {
                    return Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(48),
                            child: art,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 48, 48, 48),
                            child: controls,
                          ),
                        ),
                      ],
                    );
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
                    child: Column(
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: AspectRatio(aspectRatio: 1, child: art),
                        ),
                        const SizedBox(height: 32),
                        controls,
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _showMetadata(BuildContext context, AudioTrack track) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainer,
      builder: (_) => _MetadataSheet(track: track),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.track});
  final AudioTrack track;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.container,
        boxShadow: AppColors.ambientShadow,
        gradient: track.hasCoverArt
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primaryContainer.withOpacity(0.4),
                  AppColors.accentPurple.withOpacity(0.4),
                ],
              ),
      ),
      clipBehavior: Clip.antiAlias,
      child: track.hasCoverArt
          ? Image.file(
              File(track.coverArtPath!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() => Center(
        child: Icon(Icons.music_note,
            size: 96, color: AppColors.onSurface.withOpacity(0.5)),
      );
}

class _Controls extends StatelessWidget {
  const _Controls({required this.audio, required this.track});
  final AudioPlayerProvider audio;
  final AudioTrack track;

  @override
  Widget build(BuildContext context) {
    final playlists = context.watch<PlaylistProvider>();
    final isFav = playlists.isFavorite(track.path);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.headlineMd),
                  const SizedBox(height: 6),
                  Text('${track.artist} • ${track.album}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            IconButton(
              iconSize: 28,
              tooltip: isFav ? 'Remove from Favorites' : 'Add to Favorites',
              onPressed: () => playlists.toggleFavorite(track.path),
              icon: Icon(
                isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _Scrubber(audio: audio),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              iconSize: 26,
              tooltip: 'Shuffle',
              onPressed: audio.toggleShuffle,
              icon: Icon(Icons.shuffle,
                  color: audio.shuffle
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant),
            ),
            CircleIconButton(
              icon: Icons.skip_previous_rounded,
              iconSize: 34,
              size: 56,
              onPressed: audio.playPrevious,
              tooltip: 'Previous',
            ),
            CircleIconButton(
              icon: audio.playing
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              iconSize: 44,
              size: AppSpacing.playbackControlLarge,
              filled: true,
              glow: true,
              onPressed: audio.playOrPause,
              tooltip: audio.playing ? 'Pause' : 'Play',
            ),
            CircleIconButton(
              icon: Icons.skip_next_rounded,
              iconSize: 34,
              size: 56,
              onPressed: audio.playNext,
              tooltip: 'Next',
            ),
            IconButton(
              iconSize: 26,
              tooltip: switch (audio.repeatMode) {
                RepeatMode.off => 'Repeat off',
                RepeatMode.all => 'Repeat all',
                RepeatMode.one => 'Repeat one',
              },
              onPressed: audio.cycleRepeatMode,
              icon: Icon(
                audio.repeatMode == RepeatMode.one
                    ? Icons.repeat_one
                    : Icons.repeat,
                color: audio.repeatMode == RepeatMode.off
                    ? AppColors.onSurfaceVariant
                    : AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(height: 1),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ActionButton(
              icon: Icons.queue_music,
              label: 'Queue',
              onTap: () => _showQueue(context),
            ),
            _ActionButton(
              icon: Icons.lyrics_outlined,
              label: 'Lyrics',
              onTap: () => _showLyrics(context, track),
            ),
            _ActionButton(
              icon: Icons.speed,
              label: '${audio.speed.toStringAsFixed(2)}x',
              onTap: () => _showSpeed(context, audio),
            ),
            _ActionButton(
              icon: audio.sleepTimerActive
                  ? Icons.bedtime
                  : Icons.bedtime_outlined,
              label: audio.sleepTimerActive
                  ? Formatters.duration(audio.sleepRemaining!)
                  : 'Sleep',
              tinted: audio.sleepTimerActive,
              onTap: () => _showSleep(context, audio),
            ),
          ],
        ),
      ],
    );
  }

  void _showQueue(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surfaceContainer,
        builder: (_) => const _QueueSheet(),
      );

  void _showLyrics(BuildContext context, AudioTrack track) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surfaceContainer,
        builder: (_) => _LyricsSheet(track: track),
      );

  void _showSpeed(BuildContext context, AudioPlayerProvider audio) {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('Playback Speed', style: AppTypography.headlineMd),
            const SizedBox(height: 8),
            for (final s in speeds)
              ListTile(
                title: Text('${s.toStringAsFixed(2)}x'),
                trailing: (audio.speed - s).abs() < 0.001
                    ? Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  audio.setSpeed(s);
                  Navigator.of(context).pop();
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showSleep(BuildContext context, AudioPlayerProvider audio) {
    const options = [15, 30, 45, 60, 90];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('Sleep Timer', style: AppTypography.headlineMd),
            const SizedBox(height: 8),
            if (audio.sleepTimerActive)
              ListTile(
                leading: Icon(Icons.close, color: AppColors.error),
                title: const Text('Cancel timer'),
                onTap: () {
                  audio.cancelSleepTimer();
                  Navigator.of(context).pop();
                },
              ),
            for (final m in options)
              ListTile(
                leading: const Icon(Icons.bedtime_outlined),
                title: Text('$m minutes'),
                onTap: () {
                  audio.startSleepTimer(Duration(minutes: m));
                  Navigator.of(context).pop();
                },
              ),
            ListTile(
              leading: const Icon(Icons.music_note),
              title: const Text('End of track'),
              onTap: () {
                audio.startSleepTimer(const Duration(hours: 12),
                    stopAfterCurrent: true);
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _Scrubber extends StatefulWidget {
  const _Scrubber({required this.audio});
  final AudioPlayerProvider audio;

  @override
  State<_Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends State<_Scrubber> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final audio = widget.audio;
    final total = audio.duration.inMilliseconds.toDouble();
    final current = audio.position.inMilliseconds
        .toDouble()
        .clamp(0.0, total <= 0 ? 1.0 : total);
    final value = _dragValue ?? current;
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            min: 0,
            max: total <= 0 ? 1 : total,
            value: total <= 0 ? 0 : value.clamp(0, total),
            onChanged: total <= 0
                ? null
                : (v) => setState(() => _dragValue = v),
            onChangeEnd: total <= 0
                ? null
                : (v) {
                    audio.seek(Duration(milliseconds: v.round()));
                    setState(() => _dragValue = null);
                  },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                Formatters.duration(
                    Duration(milliseconds: value.round())),
                style: AppTypography.labelMd
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
              Text(
                Formatters.duration(audio.duration),
                style: AppTypography.labelMd
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tinted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final color =
        tinted ? AppColors.primary : AppColors.onSurfaceVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label,
                style: AppTypography.labelMd.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

class _QueueSheet extends StatelessWidget {
  const _QueueSheet();

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioPlayerProvider>();
    final queue = audio.queue;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(Icons.queue_music, color: AppColors.primary),
                const SizedBox(width: 12),
                Text('Play Queue', style: AppTypography.headlineMd),
                const Spacer(),
                Text('${queue.length} tracks',
                    style: AppTypography.labelMd
                        .copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              scrollController: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: queue.length,
              onReorder: audio.reorderQueue,
              itemBuilder: (context, index) {
                final t = queue[index];
                final isCurrent = audio.current?.path == t.path;
                return ListTile(
                  key: ValueKey(t.path),
                  leading: Icon(
                    isCurrent ? Icons.graphic_eq : Icons.drag_handle,
                    color: isCurrent
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant,
                  ),
                  title: Text(t.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(t.artist,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => audio.play(t, queue: queue),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LyricsSheet extends StatelessWidget {
  const _LyricsSheet({required this.track});
  final AudioTrack track;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.all(24),
        child: track.hasLyrics
            ? ListView(
                controller: scrollController,
                children: [
                  Text(track.title, style: AppTypography.headlineMd),
                  const SizedBox(height: 4),
                  Text(track.artist,
                      style: AppTypography.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 20),
                  Text(track.lyrics!,
                      style: AppTypography.bodyMd.copyWith(height: 1.8)),
                ],
              )
            : const EmptyState(
                icon: Icons.lyrics_outlined,
                title: 'No lyrics found',
                message:
                    'Add a matching .lrc or .txt file next to this track to '
                    'see synced or plain lyrics here.',
              ),
      ),
    );
  }
}

class _MetadataSheet extends StatelessWidget {
  const _MetadataSheet({required this.track});
  final AudioTrack track;

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, String>>[
      MapEntry('Title', track.title),
      MapEntry('Artist', track.artist),
      MapEntry('Album', track.album),
      MapEntry('Duration',
          track.probed ? Formatters.durationVerbose(track.duration) : 'Unknown'),
      MapEntry('Format', track.containerBadge),
      MapEntry('Size', Formatters.bytes(track.sizeBytes)),
      MapEntry('Folder', track.folderName),
      MapEntry('Modified', Formatters.date(track.modified)),
      MapEntry('Path', track.path),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Track Info', style: AppTypography.headlineMd),
            const SizedBox(height: 16),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(row.key,
                          style: AppTypography.labelMd.copyWith(
                              color: AppColors.onSurfaceVariant)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(row.value, style: AppTypography.bodyMd),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
