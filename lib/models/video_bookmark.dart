/// Part 3 — A user-defined bookmark (marker) at a timestamp inside a video.
class VideoBookmark {
  const VideoBookmark({
    required this.positionMs,
    required this.label,
    required this.createdAtMs,
  });

  final int positionMs;
  final String label;
  final int createdAtMs;

  Duration get position => Duration(milliseconds: positionMs);

  Map<String, dynamic> toJson() => {
        'p': positionMs,
        'l': label,
        'c': createdAtMs,
      };

  static VideoBookmark fromJson(Map<String, dynamic> j) => VideoBookmark(
        positionMs: (j['p'] as num?)?.toInt() ?? 0,
        label: j['l'] as String? ?? '',
        createdAtMs: (j['c'] as num?)?.toInt() ?? 0,
      );
}
