import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// Generates and caches JPEG thumbnails for library videos.
///
/// Thumbnails are produced with the platform `MediaMetadataRetriever`
/// (via the `video_thumbnail` plugin) and cached on disk keyed by a hash of
/// the source path + modification time, so edits invalidate stale art.
class ThumbnailService {
  ThumbnailService._();
  static final ThumbnailService instance = ThumbnailService._();

  Directory? _cacheDir;
  final Map<String, Future<File?>> _inFlight = {};

  Future<Directory> _ensureCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final base = await getApplicationCacheDirectory();
    final dir = Directory('${base.path}/thumbs');
    if (!await dir.exists()) await dir.create(recursive: true);
    _cacheDir = dir;
    return dir;
  }

  String _keyFor(String path, DateTime modified) {
    final digest =
        md5.convert(utf8.encode('$path::${modified.millisecondsSinceEpoch}'));
    return digest.toString();
  }

  /// Returns a cached (or freshly generated) thumbnail file, or null when the
  /// source cannot be decoded.
  Future<File?> thumbnailFor(String videoPath, DateTime modified) {
    final key = _keyFor(videoPath, modified);
    return _inFlight.putIfAbsent(key, () async {
      try {
        final dir = await _ensureCacheDir();
        final target = File('${dir.path}/$key.jpg');
        if (await target.exists()) return target;
        final generated = await VideoThumbnail.thumbnailFile(
          video: videoPath,
          thumbnailPath: target.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 640,
          quality: 70,
        );
        if (generated == null) return null;
        final file = File(generated);
        return await file.exists() ? file : null;
      } catch (_) {
        return null;
      } finally {
        // Allow retries on a later request if generation failed.
        Future<void>.delayed(Duration(seconds: 1), () {
          _inFlight.remove(key);
        });
      }
    });
  }

  Future<void> clearCache() async {
    final dir = await _ensureCacheDir();
    if (await dir.exists()) {
      await dir.delete(recursive: true);
      _cacheDir = null;
    }
  }
}
