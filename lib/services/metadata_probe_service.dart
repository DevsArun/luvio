import 'dart:async';
import 'dart:collection';

import 'package:media_kit/media_kit.dart';

import '../models/video_item.dart';

/// Probes media files for duration / resolution / codecs using a hidden
/// libmpv instance. Files are probed sequentially at idle priority so the UI
/// stays at 60fps; results are pushed through [onProbed] and cached by the
/// library provider.
class MetadataProbeService {
  MetadataProbeService({required this.onProbed});

  final void Function(VideoItem item) onProbed;

  final Queue<VideoItem> _queue = Queue();
  final Set<String> _queued = {};
  Player? _player;
  bool _running = false;
  bool _disposed = false;

  void enqueue(Iterable<VideoItem> items) {
    for (final item in items) {
      if (item.durationMs > 0) continue;
      if (_queued.add(item.path)) _queue.add(item);
    }
    _pump();
  }

  /// Probe a single item with priority (used by the File Information dialog).
  Future<VideoItem> probeNow(VideoItem item) async {
    await _probe(item, timeout: Duration(seconds: 12));
    return item;
  }

  Future<void> _pump() async {
    if (_running || _disposed) return;
    _running = true;
    while (_queue.isNotEmpty && !_disposed) {
      final item = _queue.removeFirst();
      _queued.remove(item.path);
      await _probe(item, timeout: Duration(seconds: 8));
      // Yield between probes to keep the raster thread free.
      await Future<void>.delayed(Duration(milliseconds: 120));
    }
    _running = false;
  }

  Future<void> _probe(VideoItem item, {required Duration timeout}) async {
    try {
      final player = _player ??= Player(
        configuration: PlayerConfiguration(
          vo: 'null',
          logLevel: MPVLogLevel.error,
        ),
      );
      final completer = Completer<void>();
      late final StreamSubscription<Duration> sub;
      sub = player.stream.duration.listen((duration) {
        if (duration > Duration.zero && !completer.isCompleted) {
          item.durationMs = duration.inMilliseconds;
          completer.complete();
        }
      });
      await player.open(Media(item.path), play: false);
      await completer.future.timeout(timeout, onTimeout: () {});
      // Give track metadata a beat to settle, then read it.
      await Future<void>.delayed(Duration(milliseconds: 200));
      item.width = player.state.width ?? item.width;
      item.height = player.state.height ?? item.height;
      final videoTracks = player.state.tracks.video;
      if (videoTracks.isNotEmpty) {
        item.videoCodec ??= videoTracks.first.codec?.toUpperCase();
      }
      final audioTracks = player.state.tracks.audio;
      if (audioTracks.isNotEmpty) {
        item.audioCodec ??= audioTracks.first.codec?.toUpperCase();
      }
      await sub.cancel();
      await player.stop();
      if (item.durationMs > 0) onProbed(item);
    } catch (_) {
      // Undecodable file — leave metadata unknown.
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _queue.clear();
    _queued.clear();
    await _player?.dispose();
    _player = null;
  }
}
