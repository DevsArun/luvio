import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/video_bookmark.dart';

/// Persists per-video bookmarks in SharedPreferences, keyed by file path.
class BookmarkService {
  static const String _prefix = 'bookmarks_v1:';

  String _key(String videoPath) => '$_prefix$videoPath';

  Future<List<VideoBookmark>> list(String videoPath) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key(videoPath)) ?? const <String>[];
    final out = <VideoBookmark>[];
    for (final s in raw) {
      try {
        out.add(VideoBookmark.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {}
    }
    out.sort((a, b) => a.positionMs.compareTo(b.positionMs));
    return out;
  }

  Future<void> add(String videoPath, VideoBookmark bookmark) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key(videoPath)) ?? <String>[];
    raw.add(jsonEncode(bookmark.toJson()));
    await prefs.setStringList(_key(videoPath), raw);
  }

  Future<void> removeAt(String videoPath, int positionMs) async {
    final prefs = await SharedPreferences.getInstance();
    final items = await list(videoPath);
    items.removeWhere((e) => e.positionMs == positionMs);
    await prefs.setStringList(
      _key(videoPath),
      items.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> clear(String videoPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(videoPath));
  }
}
