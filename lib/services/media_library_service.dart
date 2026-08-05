import 'dart:io';

import 'package:flutter/services.dart';

import '../models/storage_volume.dart';
import '../models/audio_track.dart';
import '../models/video_item.dart';

/// Discovers storage volumes and scans them for video files.
class MediaLibraryService {
  static const MethodChannel _channel = MethodChannel('luvio_player/storage');

  /// Every major video container supported by the libmpv engine.
  static const Set<String> videoExtensions = {
    'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v', '3gp', '3g2',
    'ts', 'mts', 'm2ts', 'mpg', 'mpeg', 'vob', 'ogv', 'ogm', 'rm', 'rmvb',
    'divx', 'f4v', 'asf', 'mxf', 'dv', 'mpv', 'm2v', 'dat',
  };

  /// Directories that should never be scanned.
  static const List<String> _skipSegments = [
    '/Android/data',
    '/Android/obb',
    '/Android/media/com.android',
    '/.thumbnails',
    '/.trashed',
    '/.Trash',
  ];

  /// Returns mounted volumes with capacity info (via the platform channel),
  /// falling back to the primary external storage path.
  Future<List<StorageVolume>> discoverVolumes() async {
    try {
      final result = await _channel.invokeMethod<List<dynamic>>('getVolumes');
      if (result != null && result.isNotEmpty) {
        return result
            .map((e) => StorageVolume.fromMap(e as Map<dynamic, dynamic>))
            .toList();
      }
    } on PlatformException catch (_) {
      // Fall through to the default volume below.
    } on MissingPluginException catch (_) {}
    final fallbackPath = '/storage/emulated/0';
    return [
      StorageVolume(
        path: fallbackPath,
        name: 'Internal Storage',
        isRemovable: false,
        totalBytes: 0,
        freeBytes: 0,
      ),
    ];
  }

  bool _shouldSkipDirectory(String path) {
    final name = path.substring(path.lastIndexOf('/') + 1);
    if (name.startsWith('.')) return true;
    for (final segment in _skipSegments) {
      if (path.contains(segment)) return true;
    }
    return false;
  }

  static const Set<String> audioExtensions = {
    'mp3', 'aac', 'm4a', 'm4b', 'flac', 'wav', 'ogg', 'oga', 'opus', 'wma',
    'alac', 'aiff', 'aif', 'ape', 'mka', 'ac3', 'dts', 'amr', 'mid', 'midi',
    '3ga', 'caf', 'ra',
  };

  bool isAudioFile(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1) return false;
    return audioExtensions.contains(path.substring(dot + 1).toLowerCase());
  }

  /// Asks MediaStore for every indexed audio track. Same reasoning as
  /// [queryMediaStoreVideos]: the File API alone finds nothing on Android 11+.
  Future<List<AudioTrack>> queryMediaStoreAudio() async {
    try {
      final rows = await _channel.invokeMethod<List<dynamic>>('getAudio');
      if (rows == null) return const [];
      final items = <AudioTrack>[];
      for (final row in rows) {
        try {
          final map = (row as Map).cast<dynamic, dynamic>();
          final path = map['path'] as String?;
          if (path == null || path.isEmpty) continue;
          final modifiedMs = (map['modified'] as num?)?.toInt() ?? 0;
          items.add(AudioTrack(
            path: path,
            sizeBytes: (map['size'] as num?)?.toInt() ?? 0,
            modified: modifiedMs > 0
                ? DateTime.fromMillisecondsSinceEpoch(modifiedMs)
                : DateTime.now(),
          ));
        } catch (_) {
          continue;
        }
      }
      return items;
    } catch (_) {
      return const [];
    }
  }

  Stream<AudioTrack> scanAudio(
    List<String> roots, {
    void Function(String directory)? onDirectory,
  }) async* {
    final seen = <String>{};

    // MediaStore first — reliable on every Android version.
    onDirectory?.call('Reading music library…');
    for (final track in await queryMediaStoreAudio()) {
      if (seen.add(track.path)) yield track;
    }

    for (final root in roots) {
      final dir = Directory(root);
      if (!await dir.exists()) continue;
      final queue = <Directory>[dir];
      while (queue.isNotEmpty) {
        final current = queue.removeLast();
        if (_shouldSkipDirectory(current.path)) continue;
        onDirectory?.call(current.path);
        List<FileSystemEntity> entries;
        try {
          entries = await current.list(followLinks: false).toList();
        } catch (_) {
          continue;
        }
        for (final entity in entries) {
          if (entity is Directory) {
            queue.add(entity);
          } else if (entity is File && isAudioFile(entity.path)) {
            if (!seen.add(entity.path)) continue;
            try {
              final stat = await entity.stat();
              if (stat.size < 16 * 1024) continue;
              yield AudioTrack(
                path: entity.path,
                sizeBytes: stat.size,
                modified: stat.modified,
              );
            } catch (_) {
              continue;
            }
          }
        }
      }
    }
  }

  bool isVideoFile(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1) return false;
    return videoExtensions.contains(path.substring(dot + 1).toLowerCase());
  }

  /// Asks Android's MediaStore for every indexed video.
  ///
  /// This is the primary discovery path. On Android 11+ / Fire OS 8 the app
  /// is no longer allowed to walk shared storage with the File API, so the
  /// directory crawl below silently finds nothing. MediaStore always works
  /// with the plain READ_MEDIA_VIDEO grant and also picks up files that were
  /// just copied over USB.
  Future<List<VideoItem>> queryMediaStoreVideos() async {
    try {
      final rows = await _channel.invokeMethod<List<dynamic>>('getVideos');
      if (rows == null) return const [];
      final items = <VideoItem>[];
      for (final row in rows) {
        try {
          final map = (row as Map).cast<dynamic, dynamic>();
          final path = map['path'] as String?;
          if (path == null || path.isEmpty) continue;
          final size = (map['size'] as num?)?.toInt() ?? 0;
          final modifiedMs = (map['modified'] as num?)?.toInt() ?? 0;
          final durationMs = (map['duration'] as num?)?.toInt() ?? 0;
          final width = (map['width'] as num?)?.toInt() ?? 0;
          final height = (map['height'] as num?)?.toInt() ?? 0;
          items.add(VideoItem(
            path: path,
            sizeBytes: size,
            modified: modifiedMs > 0
                ? DateTime.fromMillisecondsSinceEpoch(modifiedMs)
                : DateTime.now(),
            // VideoItem uses non-nullable ints where 0 means "not probed yet",
            // so pass the raw values straight through.
            durationMs: durationMs > 0 ? durationMs : 0,
            width: width > 0 ? width : 0,
            height: height > 0 ? height : 0,
          ));
        } catch (_) {
          continue;
        }
      }
      return items;
    } on PlatformException catch (_) {
      return const [];
    } on MissingPluginException catch (_) {
      return const [];
    }
  }

  /// True when the user granted Android's "All files access".
  Future<bool> hasAllFilesAccess() async {
    try {
      return await _channel.invokeMethod<bool>('hasAllFilesAccess') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system "All files access" screen.
  Future<bool> requestAllFilesAccess() async {
    try {
      return await _channel.invokeMethod<bool>('requestAllFilesAccess') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Streams discovered videos: MediaStore results first (instant, reliable),
  /// then a directory crawl that can add anything MediaStore missed — e.g.
  /// files on an SD card the indexer skipped. Duplicates are filtered out.
  /// Honors `.nomedia` markers.
  Stream<VideoItem> scan(
    List<String> roots, {
    void Function(String currentDirectory)? onDirectory,
  }) async* {
    final emitted = <String>{};

    // --- Pass 1: MediaStore (works without All-files access) ---------------
    onDirectory?.call('Reading media library…');
    for (final item in await queryMediaStoreVideos()) {
      if (emitted.add(item.path)) yield item;
    }

    // --- Pass 2: filesystem crawl (adds anything MediaStore missed) --------
    for (final root in roots) {
      final rootDir = Directory(root);
      if (!await rootDir.exists()) continue;
      final pending = <Directory>[rootDir];
      while (pending.isNotEmpty) {
        final dir = pending.removeLast();
        onDirectory?.call(dir.path);
        List<FileSystemEntity> entries;
        try {
          entries = await dir.list(followLinks: false).toList();
        } catch (_) {
          continue; // Unreadable directory — skip silently.
        }
        if (entries.any((e) => e is File && e.path.endsWith('/.nomedia'))) {
          continue;
        }
        for (final entity in entries) {
          if (entity is Directory) {
            if (!_shouldSkipDirectory(entity.path)) pending.add(entity);
          } else if (entity is File && isVideoFile(entity.path)) {
            if (emitted.contains(entity.path)) continue;
            try {
              final stat = await entity.stat();
              if (stat.size < 64 * 1024) continue; // Ignore tiny artifacts.
              emitted.add(entity.path);
              yield VideoItem(
                path: entity.path,
                sizeBytes: stat.size,
                modified: stat.modified,
              );
            } catch (_) {
              // Unreadable file — skip.
            }
          }
        }
      }
    }
  }

  /// Lists immediate sub-directories of [path] that (recursively) contain at
  /// least one indexed video — used by the two-pane storage browser tree.
  Future<bool> exists(String path) => File(path).exists();

  /// Deletes a file for real.
  ///
  /// A plain `File.delete()` throws on Android 11+ for files the app does not
  /// own, which is why the Delete button appeared to do nothing. The native
  /// bridge deletes the MediaStore row as well, so the file disappears from
  /// the gallery and other apps too.
  Future<bool> deleteFile(String path) async {
    try {
      final ok = await _channel.invokeMethod<bool>(
        'deleteFile',
        {'path': path},
      );
      if (ok == true) return true;
    } catch (_) {
      // Fall through to the Dart-side attempt below.
    }
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return !await file.exists();
      }
      return true; // Already gone.
    } catch (_) {
      return false;
    }
  }

  /// Tells Android's media indexer that [path] changed, so a renamed or
  /// deleted file is reflected in other apps immediately.
  Future<void> notifyMediaScanner(String path) async {
    try {
      await _channel.invokeMethod('scanFile', {'path': path});
    } catch (_) {}
  }

  Future<String?> renameFile(String path, String newTitle) async {
    final file = File(path);
    if (!await file.exists()) return null;
    final dir = path.substring(0, path.lastIndexOf('/'));
    final ext = path.substring(path.lastIndexOf('.'));
    final newPath = '$dir/$newTitle$ext';
    if (newPath == path) return path;
    try {
      await file.rename(newPath);
    } catch (_) {
      // Scoped storage refused the rename (no All-files access).
      return null;
    }
    // Keep MediaStore in sync for both the old and the new name.
    await notifyMediaScanner(path);
    await notifyMediaScanner(newPath);
    return newPath;
  }
}
