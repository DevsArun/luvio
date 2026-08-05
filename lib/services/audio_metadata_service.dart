import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart' hide AudioTrack;

import '../models/audio_track.dart';

/// Resolves offline audio metadata: duration (via a hidden libmpv instance),
/// folder cover art and sibling `.lrc` / `.txt` lyrics files. Fully local —
/// no network access.
class AudioMetadataService {
  Player? _player;
  bool _disposed = false;

  static const List<String> _coverNames = [
    'cover', 'folder', 'album', 'albumart', 'front', 'artwork', 'thumb',
  ];
  static const List<String> _imageExts = ['jpg', 'jpeg', 'png', 'webp'];

  Future<String?> findCoverArt(String folderPath) async {
    for (final base in _coverNames) {
      for (final ext in _imageExts) {
        final candidate = '$folderPath/$base.$ext';
        if (await File(candidate).exists()) return candidate;
        final upper = '$folderPath/${base.toUpperCase()}.$ext';
        if (await File(upper).exists()) return upper;
      }
    }
    return null;
  }

  Future<String?> findLyrics(String trackPath) async {
    final dot = trackPath.lastIndexOf('.');
    final stem = dot > 0 ? trackPath.substring(0, dot) : trackPath;
    for (final ext in const ['lrc', 'txt']) {
      final file = File('$stem.$ext');
      if (await file.exists()) {
        try {
          final raw = await file.readAsString();
          if (ext == 'lrc') return _stripLrcTimestamps(raw);
          return raw.trim();
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  String _stripLrcTimestamps(String raw) {
    final buffer = StringBuffer();
    final tag = RegExp(r'\[\d{1,2}:\d{1,2}(?:[.:]\d{1,3})?\]');
    final meta = RegExp(r'^\[[a-zA-Z]+:.*\]\s*$');
    for (final line in raw.split('\n')) {
      if (meta.hasMatch(line.trim())) continue;
      final cleaned = line.replaceAll(tag, '').trim();
      if (cleaned.isNotEmpty) buffer.writeln(cleaned);
    }
    final result = buffer.toString().trim();
    return result.isEmpty ? raw.trim() : result;
  }

  Future<AudioTrack> resolve(AudioTrack track) async {
    track.coverArtPath ??= await findCoverArt(track.folderPath);
    track.lyrics ??= await findLyrics(track.path);
    if (track.durationMs <= 0) {
      await _probeDuration(track);
    }
    return track;
  }

  Future<void> _probeDuration(AudioTrack track,
      {Duration timeout = const Duration(seconds: 8)}) async {
    if (_disposed) return;
    try {
      final player = _player ??= Player(
        configuration: const PlayerConfiguration(
          vo: 'null',
          logLevel: MPVLogLevel.error,
        ),
      );
      final completer = Completer<void>();
      late final StreamSubscription<Duration> sub;
      sub = player.stream.duration.listen((duration) {
        if (duration > Duration.zero && !completer.isCompleted) {
          track.durationMs = duration.inMilliseconds;
          completer.complete();
        }
      });
      await player.open(Media(track.path), play: false);
      await completer.future.timeout(timeout, onTimeout: () {});
      await sub.cancel();
      await player.stop();
    } catch (_) {
      // Undecodable file — leave duration unknown.
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await _player?.dispose();
    _player = null;
  }
}
