import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/audio_track.dart';
import '../services/audio_metadata_service.dart';
import '../services/media_library_service.dart';
import '../services/preferences_service.dart';

/// Owns the scanned audio library: tracks, folders, scan progress, resume
/// positions and recently-played history.
class AudioLibraryProvider extends ChangeNotifier {
  AudioLibraryProvider(this._prefs) {
    _metadata = AudioMetadataService();
    _restoreIndex();
  }

  final PreferencesService _prefs;
  final MediaLibraryService service = MediaLibraryService();
  late final AudioMetadataService _metadata;

  final Map<String, AudioTrack> _tracksByPath = {};

  bool isScanning = false;
  int scannedFileCount = 0;
  String currentScanDirectory = '';
  DateTime? lastScanTime;
  StreamSubscription<AudioTrack>? _scanSub;

  bool _indexRestored = false;
  bool _scanAttempted = false;
  bool get hasIndex => _tracksByPath.isNotEmpty;
  bool get indexRestored => _indexRestored;

  AudioMetadataService get metadata => _metadata;

  List<AudioTrack> get tracks {
    final list = _tracksByPath.values.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return list;
  }

  List<AudioTrack> get recentlyAdded {
    final list = _tracksByPath.values.toList()
      ..sort((a, b) => b.modified.compareTo(a.modified));
    return list;
  }

  List<AudioTrack> get recentlyPlayed {
    final list =
        _tracksByPath.values.where((t) => t.lastPlayed != null).toList()
          ..sort((a, b) => b.lastPlayed!.compareTo(a.lastPlayed!));
    return list;
  }

  AudioTrack? byPath(String path) => _tracksByPath[path];

  List<AudioFolderGroup> get folders {
    final byFolder = <String, List<AudioTrack>>{};
    for (final t in _tracksByPath.values) {
      byFolder.putIfAbsent(t.folderPath, () => []).add(t);
    }
    final list = byFolder.entries
        .map((e) => AudioFolderGroup(path: e.key, tracks: e.value))
        .toList()
      ..sort((a, b) => b.tracks.length.compareTo(a.tracks.length));
    return list;
  }

  List<AudioTrack> tracksInFolder(String folderPath) {
    final list = _tracksByPath.values
        .where((t) => t.folderPath == folderPath)
        .toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return list;
  }

  int get totalBytes =>
      _tracksByPath.values.fold(0, (sum, t) => sum + t.sizeBytes);

  List<AudioTrack> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return _tracksByPath.values
        .where((t) =>
            t.title.toLowerCase().contains(q) ||
            t.artist.toLowerCase().contains(q) ||
            t.album.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));
  }

  void _restoreIndex() {
    final cached = _prefs.getJsonList(PrefKeys.audioIndex);
    for (final json in cached) {
      try {
        final item = AudioTrack.fromJson(json);
        _tracksByPath[item.path] = item;
      } catch (_) {}
    }
    final ts = _prefs.getInt(PrefKeys.audioLastScan, 0);
    if (ts > 0) lastScanTime = DateTime.fromMillisecondsSinceEpoch(ts);
    _indexRestored = true;
  }

  Future<void> _persistIndex() async {
    await _prefs.setJsonList(
      PrefKeys.audioIndex,
      _tracksByPath.values.map((t) => t.toJson()).toList(),
    );
    await _prefs.setInt(
      PrefKeys.audioLastScan,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Timer? _persistDebounce;
  void _persistIndexDebounced() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(seconds: 3), _persistIndex);
  }

  Future<void> ensureScanned() async {
    if (_scanAttempted || hasIndex || isScanning) return;
    _scanAttempted = true;
    await startScan();
  }

  Future<void> startScan() async {
    if (isScanning) return;
    isScanning = true;
    scannedFileCount = 0;
    notifyListeners();

    final volumes = await service.discoverVolumes();
    final previousPaths = _tracksByPath.keys.toSet();
    final foundPaths = <String>{};

    final stream = service.scanAudio(
      volumes.map((v) => v.path).toList(),
      onDirectory: (dir) => currentScanDirectory = dir,
    );

    var lastNotify = DateTime.now();
    final completer = Completer<void>();
    _scanSub = stream.listen(
      (item) {
        foundPaths.add(item.path);
        if (!_tracksByPath.containsKey(item.path)) {
          _tracksByPath[item.path] = item;
          unawaited(_metadata.resolve(item).then((_) {
            _persistIndexDebounced();
            notifyListeners();
          }));
        }
        scannedFileCount++;
        if (DateTime.now().difference(lastNotify).inMilliseconds > 150) {
          lastNotify = DateTime.now();
          notifyListeners();
        }
      },
      onDone: () async {
        for (final stale in previousPaths.difference(foundPaths)) {
          _tracksByPath.remove(stale);
        }
        isScanning = false;
        lastScanTime = DateTime.now();
        await _persistIndex();
        notifyListeners();
        if (!completer.isCompleted) completer.complete();
      },
      onError: (_) {
        isScanning = false;
        notifyListeners();
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: false,
    );
    await completer.future;
  }

  Future<void> stopScan() async {
    await _scanSub?.cancel();
    _scanSub = null;
    isScanning = false;
    await _persistIndex();
    notifyListeners();
  }

  Future<AudioTrack> resolveMetadata(AudioTrack track) async {
    final resolved = await _metadata.resolve(track);
    notifyListeners();
    _persistIndexDebounced();
    return resolved;
  }

  void updatePlaybackState(
    String path, {
    required Duration position,
    Duration? duration,
  }) {
    final track = _tracksByPath[path];
    if (track == null) return;
    track.positionMs = position.inMilliseconds;
    if (duration != null && duration > Duration.zero) {
      track.durationMs = duration.inMilliseconds;
    }
    track.lastPlayed = DateTime.now();
    _persistIndexDebounced();
    notifyListeners();
  }

  /// Returns false when Android refused the delete (no All-files access).
  Future<bool> deleteTrack(AudioTrack track) async {
    final deleted = await service.deleteFile(track.path);
    if (!deleted) return false;
    _tracksByPath.remove(track.path);
    await _persistIndex();
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _persistDebounce?.cancel();
    _metadata.dispose();
    super.dispose();
  }
}

class AudioFolderGroup {
  AudioFolderGroup({required this.path, required this.tracks});

  final String path;
  final List<AudioTrack> tracks;

  String get name {
    final slash = path.lastIndexOf('/');
    return slash == -1 ? path : path.substring(slash + 1);
  }

  int get itemCount => tracks.length;
  int get totalBytes => tracks.fold(0, (sum, t) => sum + t.sizeBytes);
}
