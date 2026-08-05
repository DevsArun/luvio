/// A single playable audio file discovered on device storage.
///
/// Tags (title/artist/album) are derived offline from the file name and its
/// containing folder using the common `Artist - Title` convention, so the
/// model stays pure Dart with zero native dependencies. Cover art and lyrics
/// are resolved lazily from sibling files (see AudioMetadataService).
class AudioTrack {
  AudioTrack({
    required this.path,
    required this.sizeBytes,
    required this.modified,
    this.durationMs = 0,
    this.positionMs = 0,
    this.lastPlayed,
    this.coverArtPath,
    this.lyrics,
    String? title,
    String? artist,
    String? album,
  })  : _title = title,
        _artist = artist,
        _album = album;

  final String path;
  final int sizeBytes;
  final DateTime modified;

  int durationMs;
  int positionMs;
  DateTime? lastPlayed;

  String? coverArtPath;
  String? lyrics;

  String? _title;
  String? _artist;
  String? _album;

  String get name {
    final slash = path.lastIndexOf('/');
    return slash == -1 ? path : path.substring(slash + 1);
  }

  String get fileName => name;

  String get baseName {
    final n = name;
    final dot = n.lastIndexOf('.');
    return dot <= 0 ? n : n.substring(0, dot);
  }

  String get folderPath {
    final slash = path.lastIndexOf('/');
    return slash <= 0 ? '/' : path.substring(0, slash);
  }

  String get folderName {
    final f = folderPath;
    final slash = f.lastIndexOf('/');
    return slash == -1 ? f : f.substring(slash + 1);
  }

  String get extension {
    final dot = name.lastIndexOf('.');
    return dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
  }

  String get title {
    final explicit = _title;
    if (explicit != null && explicit.trim().isNotEmpty) return explicit;
    final raw = baseName;
    final sep = raw.indexOf(' - ');
    if (sep > 0 && sep + 3 < raw.length) {
      return raw.substring(sep + 3).trim();
    }
    return raw;
  }

  String get artist {
    final explicit = _artist;
    if (explicit != null && explicit.trim().isNotEmpty) return explicit;
    final raw = baseName;
    final sep = raw.indexOf(' - ');
    if (sep > 0) return raw.substring(0, sep).trim();
    return 'Unknown artist';
  }

  String get album {
    final explicit = _album;
    if (explicit != null && explicit.trim().isNotEmpty) return explicit;
    return folderName;
  }

  Duration get duration => Duration(milliseconds: durationMs);
  Duration get position => Duration(milliseconds: positionMs);

  bool get probed => durationMs > 0;
  bool get hasCoverArt => coverArtPath != null && coverArtPath!.isNotEmpty;
  bool get hasLyrics => lyrics != null && lyrics!.trim().isNotEmpty;

  bool get isNew => DateTime.now().difference(modified).inDays < 7;

  String get containerBadge =>
      extension.isEmpty ? 'AUDIO' : extension.toUpperCase();

  Map<String, dynamic> toJson() => {
        'path': path,
        'size': sizeBytes,
        'modified': modified.millisecondsSinceEpoch,
        'durationMs': durationMs,
        'positionMs': positionMs,
        'lastPlayed': lastPlayed?.millisecondsSinceEpoch,
        'cover': coverArtPath,
        'title': _title,
        'artist': _artist,
        'album': _album,
      };

  factory AudioTrack.fromJson(Map<String, dynamic> json) => AudioTrack(
        path: json['path'] as String,
        sizeBytes: (json['size'] as num?)?.toInt() ?? 0,
        modified: DateTime.fromMillisecondsSinceEpoch(
          (json['modified'] as num?)?.toInt() ?? 0,
        ),
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
        positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
        lastPlayed: json['lastPlayed'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                (json['lastPlayed'] as num).toInt(),
              ),
        coverArtPath: json['cover'] as String?,
        title: json['title'] as String?,
        artist: json['artist'] as String?,
        album: json['album'] as String?,
      );

  @override
  bool operator ==(Object other) => other is AudioTrack && other.path == path;

  @override
  int get hashCode => path.hashCode;
}
