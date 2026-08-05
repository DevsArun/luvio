/// A user-curated playlist referencing media by path.
class Playlist {
  Playlist({
    required this.id,
    required this.name,
    required this.iconName,
    required this.createdAt,
    List<String>? videoPaths,
    this.isFavorites = false,
  }) : videoPaths = videoPaths ?? [];

  final String id;
  String name;

  /// Material symbol-ish icon key: movie, favorite, audiotrack, child_care,
  /// flight, folder — mapped to Material icons in the UI layer.
  String iconName;

  final DateTime createdAt;
  final List<String> videoPaths;

  /// The built-in Favorites playlist cannot be deleted or renamed.
  final bool isFavorites;

  int get itemCount => videoPaths.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': iconName,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'paths': videoPaths,
        'favorites': isFavorites,
      };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'] as String,
        name: json['name'] as String,
        iconName: json['icon'] as String? ?? 'movie',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (json['createdAt'] as num?)?.toInt() ?? 0,
        ),
        videoPaths:
            (json['paths'] as List?)?.cast<String>().toList() ?? <String>[],
        isFavorites: json['favorites'] as bool? ?? false,
      );
}
