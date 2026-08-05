/// A mounted storage volume (internal, SD card, USB drive).
class StorageVolume {
  const StorageVolume({
    required this.path,
    required this.name,
    required this.isRemovable,
    required this.totalBytes,
    required this.freeBytes,
  });

  final String path;
  final String name;
  final bool isRemovable;
  final int totalBytes;
  final int freeBytes;

  int get usedBytes => (totalBytes - freeBytes).clamp(0, totalBytes);

  double get usedFraction =>
      totalBytes <= 0 ? 0 : (usedBytes / totalBytes).clamp(0.0, 1.0);

  bool get isInternal => !isRemovable;

  factory StorageVolume.fromMap(Map<dynamic, dynamic> map) => StorageVolume(
        path: map['path'] as String,
        name: map['name'] as String? ??
            ((map['removable'] as bool? ?? false) ? 'SD Card' : 'Internal Storage'),
        isRemovable: map['removable'] as bool? ?? false,
        totalBytes: (map['total'] as num?)?.toInt() ?? 0,
        freeBytes: (map['free'] as num?)?.toInt() ?? 0,
      );
}
