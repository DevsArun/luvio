import 'formatters_shim.dart';

/// A single playable media file discovered on device storage.
class VideoItem {
  VideoItem({
    required this.path,
    required this.sizeBytes,
    required this.modified,
    this.durationMs = 0,
    this.width = 0,
    this.height = 0,
    this.videoCodec,
    this.audioCodec,
    this.positionMs = 0,
    this.lastPlayed,
  });

  /// Absolute file path (also the stable identity of the item).
  final String path;
  final int sizeBytes;
  final DateTime modified;

  // Probed lazily (metadata probe / first playback).
  int durationMs;
  int width;
  int height;
  String? videoCodec;
  String? audioCodec;

  // Resume state.
  int positionMs;
  DateTime? lastPlayed;

  String get name {
    final slash = path.lastIndexOf('/');
    return slash == -1 ? path : path.substring(slash + 1);
  }

  /// File name without extension — used as the display title.
  String get title {
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

  Duration get duration => Duration(milliseconds: durationMs);

  Duration get position => Duration(milliseconds: positionMs);

  /// 0..1 watched fraction (0 when duration is unknown or unwatched).
  double get progress {
    if (durationMs <= 0 || positionMs <= 0) return 0.0;
    final p = positionMs / durationMs;
    return p.clamp(0.0, 1.0);
  }

  /// Whether the item should surface in "Continue Watching".
  bool get inProgress => progress > 0.01 && progress < 0.97;

  /// Added within the last 7 days → shows the cyan NEW badge.
  bool get isNew => DateTime.now().difference(modified).inDays < 7;

  String? get resolutionBadge => FormattersShim.resolutionBadge(width, height);

  /// File name including extension (alias of [name]).
  String get fileName => name;

  /// Whether duration metadata has been probed.
  bool get probed => durationMs > 0;

  /// Uppercase container badge, e.g. "MKV".
  String get containerBadge =>
      extension.isEmpty ? 'FILE' : extension.toUpperCase();

  Map<String, dynamic> toJson() => {
        'path': path,
        'size': sizeBytes,
        'modified': modified.millisecondsSinceEpoch,
        'durationMs': durationMs,
        'width': width,
        'height': height,
        'videoCodec': videoCodec,
        'audioCodec': audioCodec,
        'positionMs': positionMs,
        'lastPlayed': lastPlayed?.millisecondsSinceEpoch,
      };

  factory VideoItem.fromJson(Map<String, dynamic> json) => VideoItem(
        path: json['path'] as String,
        sizeBytes: (json['size'] as num?)?.toInt() ?? 0,
        modified: DateTime.fromMillisecondsSinceEpoch(
          (json['modified'] as num?)?.toInt() ?? 0,
        ),
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
        width: (json['width'] as num?)?.toInt() ?? 0,
        height: (json['height'] as num?)?.toInt() ?? 0,
        videoCodec: json['videoCodec'] as String?,
        audioCodec: json['audioCodec'] as String?,
        positionMs: (json['positionMs'] as num?)?.toInt() ?? 0,
        lastPlayed: json['lastPlayed'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                (json['lastPlayed'] as num).toInt(),
              ),
      );

  @override
  bool operator ==(Object other) => other is VideoItem && other.path == path;

  @override
  int get hashCode => path.hashCode;
}
