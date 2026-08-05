/// Tiny model-layer mirror of the resolution badge logic so models stay free
/// of Flutter imports (clean architecture: models are pure Dart).
abstract final class FormattersShim {
  static String? resolutionBadge(int? width, int? height) {
    if (width == null || height == null || width == 0) return null;
    final w = width >= height ? width : height;
    if (w >= 3600) return '4K';
    if (w >= 2500) return '2K';
    if (w >= 1880) return '1080p';
    if (w >= 1200) return '720p';
    return 'SD';
  }
}
