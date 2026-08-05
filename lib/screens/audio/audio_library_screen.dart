import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/storage_access.dart';

import '../../core/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../models/audio_track.dart';
import '../../providers/audio_library_provider.dart';
import '../../providers/audio_player_provider.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/media/audio_track_tile.dart';

/// The "All Audio" section: browse every scanned track or jump into a folder,
/// search, shuffle-all, and a persistent mini-player docked at the bottom.
class AudioLibraryScreen extends StatefulWidget {
  const AudioLibraryScreen({super.key});

  @override
  State<AudioLibraryScreen> createState() => _AudioLibraryScreenState();
}

class _AudioLibraryScreenState extends State<AudioLibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AudioLibraryProvider>().ensureScanned();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<AudioLibraryProvider>();
    final results = _query.isEmpty ? null : library.search(_query);

    return Material(
      color: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, library),
            if (results != null)
              Expanded(child: _buildSearchResults(context, results))
            else ...[
              TabBar(
                controller: _tabs,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.onSurfaceVariant,
                indicatorColor: AppColors.primary,
                tabs: const [
                  Tab(text: 'Tracks'),
                  Tab(text: 'Folders'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _buildTracks(context, library),
                    _buildFolders(context, library),
                  ],
                ),
              ),
            ],
            const _MiniPlayerBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AudioLibraryProvider library) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Audio', style: AppTypography.headlineMd),
              const SizedBox(width: 12),
              if (library.isScanning)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const Spacer(),
              IconButton(
                tooltip: 'Rescan audio',
                onPressed: library.isScanning
                    ? library.stopScan
                    : library.startScan,
                icon: Icon(
                    library.isScanning ? Icons.stop : Icons.refresh),
              ),
              FilledButton.tonalIcon(
                onPressed: library.tracks.isEmpty
                    ? null
                    : () => _shuffleAll(context, library),
                icon: const Icon(Icons.shuffle),
                label: const Text('Shuffle all'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            library.isScanning
                ? 'Scanning… ${library.scannedFileCount} found'
                : '${library.tracks.length} tracks • '
                    '${Formatters.bytes(library.totalBytes)}',
            style: AppTypography.labelMd
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search title, artist or album',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              fillColor: AppColors.surfaceContainerHigh,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTracks(BuildContext context, AudioLibraryProvider library) {
    final tracks = library.tracks;
    if (tracks.isEmpty) {
      return _emptyOrScanning(library);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return _trackTile(context, track, tracks);
      },
    );
  }

  Widget _buildFolders(BuildContext context, AudioLibraryProvider library) {
    final folders = library.folders;
    if (folders.isEmpty) {
      return _emptyOrScanning(library);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: folders.length,
      itemBuilder: (context, index) {
        final folder = folders[index];
        return Card(
          color: AppColors.surfaceContainer,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: ExpansionTile(
            leading: Icon(Icons.folder, color: AppColors.primary),
            title: Text(folder.name,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${folder.itemCount} tracks • '
              '${Formatters.bytes(folder.totalBytes)}',
              style: AppTypography.labelMd
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.play_circle_fill),
              color: AppColors.primary,
              tooltip: 'Play folder',
              onPressed: () => _playFolder(context, folder),
            ),
            children: folder.tracks
                .map((t) => _trackTile(context, t, folder.tracks))
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildSearchResults(BuildContext context, List<AudioTrack> results) {
    if (results.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'No matches',
        message: 'No tracks match your search.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: results.length,
      itemBuilder: (context, index) =>
          _trackTile(context, results[index], results),
    );
  }

  Widget _emptyOrScanning(AudioLibraryProvider library) {
    if (library.isScanning) {
      return const Center(child: CircularProgressIndicator());
    }
    return const EmptyState(
      icon: Icons.library_music_outlined,
      title: 'No audio yet',
      message:
          'We could not find any audio files on your device. Tap refresh '
          'to scan again.',
    );
  }

  Widget _trackTile(
      BuildContext context, AudioTrack track, List<AudioTrack> queue) {
    final audio = context.watch<AudioPlayerProvider>();
    return AudioTrackTile(
      track: track,
      isPlaying: audio.current?.path == track.path,
      onTap: () => _openTrack(context, track, queue),
      onMore: () => _showTrackMenu(context, track),
    );
  }

  void _openTrack(
      BuildContext context, AudioTrack track, List<AudioTrack> queue) {
    context.read<AudioPlayerProvider>().play(track, queue: queue);
    Navigator.of(context).pushNamed(Routes.audioPlayer);
  }

  void _shuffleAll(BuildContext context, AudioLibraryProvider library) {
    final tracks = List<AudioTrack>.of(library.tracks)..shuffle();
    if (tracks.isEmpty) return;
    final audio = context.read<AudioPlayerProvider>();
    if (!audio.shuffle) audio.toggleShuffle();
    audio.play(tracks.first, queue: tracks);
    Navigator.of(context).pushNamed(Routes.audioPlayer);
  }

  void _playFolder(BuildContext context, AudioFolderGroup folder) {
    if (folder.tracks.isEmpty) return;
    context
        .read<AudioPlayerProvider>()
        .play(folder.tracks.first, queue: folder.tracks);
    Navigator.of(context).pushNamed(Routes.audioPlayer);
  }

  void _showTrackMenu(BuildContext context, AudioTrack track) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('Play'),
              onTap: () {
                Navigator.of(context).pop();
                _openTrack(context, track, [track]);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: Text('Play folder: ${track.folderName}',
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.of(context).pop();
                final lib = context.read<AudioLibraryProvider>();
                final tracks = lib.tracksInFolder(track.folderPath);
                context
                    .read<AudioPlayerProvider>()
                    .play(track, queue: tracks);
                Navigator.of(context).pushNamed(Routes.audioPlayer);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('Delete from device'),
              onTap: () async {
                final messengerContext = context;
                Navigator.of(context).pop();
                final ok = await messengerContext
                    .read<AudioLibraryProvider>()
                    .deleteTrack(track);
                if (!messengerContext.mounted) return;
                if (ok) {
                  showActionResult(messengerContext, 'Track deleted');
                } else {
                  showStorageAccessNeeded(messengerContext, action: 'delete');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPlayerBar extends StatelessWidget {
  const _MiniPlayerBar();

  @override
  Widget build(BuildContext context) {
    final audio = context.watch<AudioPlayerProvider>();
    if (!audio.isActive) return const SizedBox.shrink();
    final track = audio.current!;
    return Material(
      color: AppColors.surfaceContainerHigh,
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(Routes.audioPlayer),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: audio.progressFraction,
              minHeight: 2,
              backgroundColor: AppColors.outline.withOpacity(0.3),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: AppColors.surfaceContainerHighest,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: track.hasCoverArt
                        ? Image.file(File(track.coverArtPath!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.music_note))
                        : const Icon(Icons.music_note),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMd
                                .copyWith(fontWeight: FontWeight.w600)),
                        Text(track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.labelMd.copyWith(
                                color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(audio.playing
                        ? Icons.pause
                        : Icons.play_arrow),
                    onPressed: audio.playOrPause,
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: audio.playNext,
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
