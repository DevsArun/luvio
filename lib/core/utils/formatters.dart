import 'package:intl/intl.dart';

/// Formatting helpers shared across the app.
abstract final class Formatters {
  /// `2:15:30`, `45:10`, `0:58`
  static String duration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    final two = NumberFormat('00');
    if (hours > 0) {
      return '$hours:${two.format(minutes)}:${two.format(seconds)}';
    }
    return '$minutes:${two.format(seconds)}';
  }

  /// `2h 15m 43s` style used by the File Information dialog.
  static String durationVerbose(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  /// `12.4 GB`, `850 MB`, `320 KB`
  static String bytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).round()} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).round()} KB';
    }
    return '$bytes B';
  }

  /// `Oct 12, 2023`
  static String date(DateTime date) => DateFormat('MMM dd, yyyy').format(date);

  /// `2 days ago`, `1 week ago`, `Just now`
  static String relativeDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
    if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '$weeks week${weeks == 1 ? '' : 's'} ago';
    }
    return date2(date);
  }

  static String date2(DateTime date) => DateFormat('MMM d, yyyy').format(date);

  /// Resolution badge: `4K`, `2K`, `1080p`, `720p`, `SD`.
  static String? resolutionBadge(int? width, int? height) {
    if (width == null || height == null || width == 0) return null;
    final w = width >= height ? width : height;
    if (w >= 3600) return '4K';
    if (w >= 2500) return '2K';
    if (w >= 1880) return '1080p';
    if (w >= 1200) return '720p';
    return 'SD';
  }

  /// Uppercased container extension: `MKV`, `MP4`.
  static String containerBadge(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return 'VIDEO';
    return path.substring(dot + 1).toUpperCase();
  }

  /// `71%` style used on storage meters.
  static String percent(double fraction) => '${(fraction * 100).round()}%';
}
