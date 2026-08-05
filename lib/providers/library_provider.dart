import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/media_folder.dart';
import '../models/storage_volume.dart';
import '../models/video_item.dart';
import '../services/media_library_service.dart';
import '../services/metadata_probe_service.dart';
import '../services/preferences_service.dart';
import '../services/vault_service.dart';

/// Owns the scanned media library: volumes, videos, folders, scan progress,
/// resume positions and recent searches.
class LibraryProvider extends ChangeNotifier {
  LibraryProvider(this._prefs, this._vaultService) {
    _probe = MetadataProbeService(onProbed: _onItemProbed);
    _restoreIndex();
  }

  final PreferencesService _prefs;
  final VaultService _vaultService;
  final MediaLibraryService service = MediaLibraryService();
  late final MetadataProbeService _probe;

  final Map<String, VideoItem> _videosByPath = {};
  List<StorageVolume> volumes = [];

  // --- Scan state -------------------------------------------------------------
  bool isScanning = false;
  int scannedFileCount = 0;
  String currentScanDirectory = '';
  final List<VideoItem> recentlyFound = [];
  DateTime? lastScanTime;
  StreamSubscription<VideoItem>? _scanSub;

  bool _indexRestored = false;
  bool get hasIndex => _videosByPath.isNotEmpty;
  bool get indexRestored => _indexRestored;

  // --- Derived views ------------------------------------------------------------

  /// All non-vaulted videos.
  List<VideoItem> get videos {
    final hidden = _vaultService.vaultPaths.toSet();
    return _videosByPath.values
        .where((v) => !hidden.contains(v.path))
        .toList();
  }

  /// Videos currently hidden inside the Private Vault.
  List<VideoItem> get vaultVideos {
    final hidden = _vaultService.vaultPaths.toSet();
    return _videosByPath.values
        .where((v) => hidden.contains(v.path))
        .toList()
      ..sort((a, b) => b.modified.compareTo(a.modified));
  }

  VideoItem? byPath(String path) => _videosByPath[path];

  List<VideoItem> get recentlyAdded {
    final list = videos..sort((a, b) => b.modified.compareTo(a.modified));
    return list;
  }

  List<VideoItem> get continueWatching {
    final list = videos.where((v) => v.inProgress).toList()
      ..sort((a, b) => (b.lastPlayed ?? b.modified)
          .compareTo(a.lastPlayed ?? a.modified));
    return list;
  }

  List<VideoItem> get recentlyPlayed {
    final list = videos.where((v) => v.lastPlayed != null).toList()
      ..sort((a, b) => b.lastPlayed!.compareTo(a.lastPlayed!));
    return list;
  }

  /// Folders that directly contain videos, sorted by size desc.
  List<MediaFolder> get folders {
    final byFolder = <String, List<VideoItem>>{};
    for (final v in videos) {
      byFolder.putIfAbsent(v.folderPath, () => []).add(v);
    }
    final list = byFolder.entries
        .map((e) => MediaFolder(path: e.key, videos: e.value))
        .toList()
      ..sort((a, b) => b.totalBytes.compareTo(a.totalBytes));
    return list;
  }

  MediaFolder? folderAt(String path) {
    final matches = videos.where((v) => v.folderPath == path).toList();
    if (matches.isEmpty) return null;
    return MediaFolder(path: path, videos: matches);
  }

  /// Sub-folders (relative to [rootPath]) that contain videos anywhere below
  /// them — powers the LOCATIONS tree in the storage browser.
  List<String> childFolderPaths(String rootPath) {
    final children = <String>{};
    final prefix = '$rootPath/';
    for (final v in videos) {
      if (v.folderPath == rootPath) continue;
      if (v.folderPath.startsWith(prefix)) {
        final rest = v.folderPath.substring(prefix.length);
        final firstSegment = rest.split('/').first;
        children.add('$rootPath/$firstSegment');
      }
    }
    final list = children.toList()..sort();
    return list;
  }

  int totalBytesUnder(String rootPath) {
    final prefix = '$rootPath/';
    return videos
        .where((v) => v.folderPath == rootPath || v.folderPath.startsWith(prefix))
        .fold(0, (sum, v) => sum + v.sizeBytes);
  }

  int itemCountUnder(String rootPath) {
    final prefix = '$rootPath/';
    return videos
        .where((v) => v.folderPath == rootPath || v.folderPath.startsWith(prefix))
        .length;
  }

  List<VideoItem> videosUnder(String rootPath) {
    final prefix = '$rootPath/';
    return videos
        .where((v) => v.folderPath == rootPath || v.folderPath.startsWith(prefix))
        .toList();
  }

  // --- Search ---------------------------------------------------------------------
  List<String> get recentSearches =>
      _prefs.getStringList(PrefKeys.recentSearches);

  Future<void> addRecentSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final list = [...recentSearches]..remove(trimmed);
    list.insert(0, trimmed);
    await _prefs.setStringList(
      PrefKeys.recentSearches,
      list.take(8).toList(),
    );
    notifyListeners();
  }

  Future<void> clearRecentSearches() async {
    await _prefs.setStringList(PrefKeys.recentSearches, []);
    notifyListeners();
  }

  List<VideoItem> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return videos
        .where((v) =>
            v.title.toLowerCase().contains(q) ||
            v.folderName.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));
  }

  // --- Lifecycle -----------------------------------------------------------------

  Future<void> refreshVolumes() async {
    volumes = await service.discoverVolumes();
    notifyListeners();
  }

  void _restoreIndex() {
    final cached = _prefs.getJsonList(PrefKeys.libraryIndex);
    for (final json in cached) {
      try {
        final item = VideoItem.fromJson(json);
        _videosByPath[item.path] = item;
      } catch (_) {}
    }
    final ts = _prefs.getInt(PrefKeys.lastScanTime, 0);
    if (ts > 0) lastScanTime = DateTime.fromMillisecondsSinceEpoch(ts);
    _indexRestored = true;
  }

  Future<void> _persistIndex() async {
    await _prefs.setJsonList(
      PrefKeys.libraryIndex,
      _videosByPath.values.map((v) => v.toJson()).toList(),
    );
    await _prefs.setInt(
      PrefKeys.lastScanTime,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Full storage scan. Streams results into the library in real time.
  Future<void> startScan() async {
    if (isScanning) return;
    isScanning = true;
    scannedFileCount = 0;
    recentlyFound.clear();
    notifyListeners();

    await refreshVolumes();
    final previousPaths = _videosByPath.keys.toSet();
    final foundPaths = <String>{};

    final stream = service.scan(
      volumes.map((v) => v.path).toList(),
      onDirectory: (dir) => currentScanDirectory = dir,
    );

    var lastNotify = DateTime.now();
    _scanSub = stream.listen(
      (item) {
        foundPaths.add(item.path);
        final existing = _videosByPath[item.path];
        if (existing != null) {
          // Keep resume metadata; refresh file stats.
          existing
            ..durationMs = existing.durationMs
            ..positionMs = existing.positionMs;
        } else {
          _videosByPath[item.path] = item;
          recentlyFound.insert(0, item);
          if (recentlyFound.length > 30) recentlyFound.removeLast();
          _probe.enqueue([item]);
        }
        scannedFileCount++;
        // Throttle UI updates to ~8fps during heavy IO.
        if (DateTime.now().difference(lastNotify).inMilliseconds > 120) {
          lastNotify = DateTime.now();
          notifyListeners();
        }
      },
      onDone: () async {
        // Drop entries whose files vanished since the previous scan.
        for (final stale in previousPaths.difference(foundPaths)) {
          _videosByPath.remove(stale);
        }
        isScanning = false;
        lastScanTime = DateTime.now();
        await _persistIndex();
        notifyListeners();
      },
      onError: (_) {
        isScanning = false;
        notifyListeners();
      },
    );
    await _scanSub!.asFuture<void>().catchError((_) {});
  }

  Future<void> stopScan() async {
    await _scanSub?.cancel();
    _scanSub = null;
    isScanning = false;
    await _persistIndex();
    notifyListeners();
  }

  void _onItemProbed(VideoItem item) {
    notifyListeners();
    _persistIndexDebounced();
  }

  Timer? _persistDebounce;
  void _persistIndexDebounced() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(Duration(seconds: 3), _persistIndex);
  }

  /// Called by the player while media plays — updates resume state.
  void updatePlaybackState(
    String path, {
    required Duration position,
    Duration? duration,
    int? width,
    int? height,
  }) {
    final item = _videosByPath[path];
    if (item == null) return;
    item.positionMs = position.inMilliseconds;
    if (duration != null && duration > Duration.zero) {
      item.durationMs = duration.inMilliseconds;
    }
    if (width != null && width > 0) item.width = width;
    if (height != null && height > 0) item.height = height;
    item.lastPlayed = DateTime.now();
    _persistIndexDebounced();
    notifyListeners();
  }

  Future<VideoItem> probeNow(VideoItem item) async {
    final result = await _probe.probeNow(item);
    notifyListeners();
    _persistIndexDebounced();
    return result;
  }

  // --- Mutations ------------------------------------------------------------------
  /// Deletes the underlying file and drops it from the index.
  /// Returns false when Android refused the delete (no All-files access),
  /// so the UI can tell the user instead of silently doing nothing.
  Future<bool> deleteVideo(VideoItem item) async {
    final deleted = await service.deleteFile(item.path);
    if (!deleted) return false;
    _videosByPath.remove(item.path);
    await _persistIndex();
    notifyListeners();
    return true;
  }

  Future<bool> renameVideo(VideoItem item, String newTitle) async {
    final newPath = await service.renameFile(item.path, newTitle);
    if (newPath == null) return false;
    _videosByPath.remove(item.path);
    _videosByPath[newPath] = VideoItem(
      path: newPath,
      sizeBytes: item.sizeBytes,
      modified: item.modified,
      durationMs: item.durationMs,
      width: item.width,
      height: item.height,
      videoCodec: item.videoCodec,
      audioCodec: item.audioCodec,
      positionMs: item.positionMs,
      lastPlayed: item.lastPlayed,
    );
    await _persistIndex();
    notifyListeners();
    return true;
  }

  /// Notify listeners after vault membership changes.
  // --- UI-layer helpers -------------------------------------------------------
  bool get scanning => isScanning;

  int get totalLibraryBytes => videos.fold(0, (sum, v) => sum + v.sizeBytes);

  List<VideoItem> videosInFolder(String folderPath) =>
      videos.where((v) => v.folderPath == folderPath).toList();

  Future<void> removeRecentSearch(String query) async {
    final updated = recentSearches.where((q) => q != query).toList();
    await _prefs.setStringList(PrefKeys.recentSearches, updated);
    notifyListeners();
  }

  void vaultChanged() => notifyListeners();

  @override
  void dispose() {
    _scanSub?.cancel();
    _persistDebounce?.cancel();
    _probe.dispose();
    super.dispose();
  }
}
