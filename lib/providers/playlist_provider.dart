import 'package:flutter/foundation.dart';

import '../models/playlist.dart';
import '../services/preferences_service.dart';

/// Manages user playlists, including the built-in Favorites collection.
class PlaylistProvider extends ChangeNotifier {
  PlaylistProvider(this._prefs) {
    _load();
  }

  final PreferencesService _prefs;
  final List<Playlist> _playlists = [];

  List<Playlist> get playlists => List.unmodifiable(_playlists);

  Playlist get favorites =>
      _playlists.firstWhere((p) => p.isFavorites);

  Playlist? byId(String id) {
    for (final p in _playlists) {
      if (p.id == id) return p;
    }
    return null;
  }

  void _load() {
    final stored = _prefs.getJsonList(PrefKeys.playlists);
    _playlists
      ..clear()
      ..addAll(stored.map(Playlist.fromJson));
    if (!_playlists.any((p) => p.isFavorites)) {
      _playlists.insert(
        0,
        Playlist(
          id: 'favorites',
          name: 'Favorites',
          iconName: 'favorite',
          createdAt: DateTime.now(),
          isFavorites: true,
        ),
      );
      _persist();
    }
  }

  Future<void> _persist() => _prefs.setJsonList(
        PrefKeys.playlists,
        _playlists.map((p) => p.toJson()).toList(),
      );

  Playlist createPlaylist(String name, {String iconName = 'movie'}) {
    final playlist = Playlist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      iconName: iconName,
      createdAt: DateTime.now(),
    );
    _playlists.add(playlist);
    _persist();
    notifyListeners();
    return playlist;
  }

  void renamePlaylist(Playlist playlist, String name) {
    if (playlist.isFavorites) return;
    playlist.name = name;
    _persist();
    notifyListeners();
  }

  void deletePlaylist(Playlist playlist) {
    if (playlist.isFavorites) return;
    _playlists.removeWhere((p) => p.id == playlist.id);
    _persist();
    notifyListeners();
  }

  void addToPlaylist(Playlist playlist, String videoPath) {
    if (!playlist.videoPaths.contains(videoPath)) {
      playlist.videoPaths.add(videoPath);
      _persist();
      notifyListeners();
    }
  }

  void removeFromPlaylist(Playlist playlist, String videoPath) {
    playlist.videoPaths.remove(videoPath);
    _persist();
    notifyListeners();
  }

  void reorder(Playlist playlist, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final path = playlist.videoPaths.removeAt(oldIndex);
    playlist.videoPaths.insert(newIndex, path);
    _persist();
    notifyListeners();
  }

  bool isFavorite(String videoPath) =>
      favorites.videoPaths.contains(videoPath);

  void toggleFavorite(String videoPath) {
    if (isFavorite(videoPath)) {
      removeFromPlaylist(favorites, videoPath);
    } else {
      addToPlaylist(favorites, videoPath);
    }
  }

  /// Removes a (deleted/renamed) path from every playlist.
  /// Whether [playlist] already references the video at [videoPath].
  bool contains(Playlist playlist, String videoPath) =>
      playlist.videoPaths.contains(videoPath);

  void purgePath(String videoPath) {
    var changed = false;
    for (final p in _playlists) {
      changed = p.videoPaths.remove(videoPath) || changed;
    }
    if (changed) {
      _persist();
      notifyListeners();
    }
  }
}
