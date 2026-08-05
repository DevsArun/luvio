import 'video_item.dart';

/// A folder aggregation of scanned videos.
class MediaFolder {
  MediaFolder({required this.path, required this.videos});

  final String path;
  final List<VideoItem> videos;

  String get name {
    final slash = path.lastIndexOf('/');
    return slash == -1 ? path : path.substring(slash + 1);
  }

  int get itemCount => videos.length;

  /// Alias of [itemCount].
  int get videoCount => videos.length;

  int get totalBytes => videos.fold(0, (sum, v) => sum + v.sizeBytes);

  DateTime get lastModified => videos.fold(
        DateTime.fromMillisecondsSinceEpoch(0),
        (latest, v) => v.modified.isAfter(latest) ? v.modified : latest,
      );

  /// Parent folder path, or null when at a storage root.
  String? get parentPath {
    final slash = path.lastIndexOf('/');
    return slash <= 0 ? null : path.substring(0, slash);
  }
}
