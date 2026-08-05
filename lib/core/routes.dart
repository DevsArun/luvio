import 'package:flutter/material.dart';

import '../models/video_item.dart';
import '../screens/about/about_screen.dart';
import '../screens/audio/audio_player_screen.dart';
import '../screens/files/file_manager_screen.dart';
import '../screens/network/network_stream_screen.dart';
import '../screens/onboarding/permissions_screen.dart';
import '../screens/player/video_player_screen.dart';
import '../screens/playlists/playlist_detail_screen.dart';
import '../screens/scan/scan_storage_screen.dart';
import '../screens/search/search_screen.dart';
import '../screens/shell/app_shell.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/videos/folder_videos_screen.dart';
import 'constants/app_spacing.dart';

/// Arguments for the fullscreen video player route.
class PlayerScreenArgs {
  const PlayerScreenArgs({this.video, this.queue, this.fromPip = false});

  /// The video to open. When null (e.g. re-entering from PiP), the player
  /// resumes the session already active in [PlayerProvider].
  final VideoItem? video;

  /// Optional play queue surrounding [video].
  final List<VideoItem>? queue;

  /// True when the route is being restored from the PiP overlay window.
  final bool fromPip;
}

/// Central route table.
abstract final class Routes {
  static const String splash = '/';
  static const String permissions = '/permissions';
  static const String shell = '/shell';
  static const String search = '/search';
  static const String scan = '/scan';
  static const String player = '/player';
  static const String audioPlayer = '/audio-player';
  static const String files = '/files';
  static const String networkStream = '/network-stream';
  static const String folderVideos = '/folder-videos';
  static const String playlistDetail = '/playlist-detail';
  static const String about = '/about';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case permissions:
        return _fade(PermissionsScreen(), settings);
      case shell:
        return _fade(
          AppShell(initialSection: _sectionFrom(settings.arguments)),
          settings,
        );
      case search:
        return _fade(SearchScreen(), settings);
      case scan:
        return _fade(ScanStorageScreen(), settings);
      case about:
        return _fade(AboutScreen(), settings);
      case folderVideos:
        return _fade(
          FolderVideosScreen(folderPath: settings.arguments as String),
          settings,
        );
      case playlistDetail:
        return _fade(
          PlaylistDetailScreen(playlistId: settings.arguments as String),
          settings,
        );
      case player:
        final args = settings.arguments;
        return _fade(
          VideoPlayerScreen(
            args: args is PlayerScreenArgs ? args : PlayerScreenArgs(),
          ),
          settings,
        );
      case audioPlayer:
        return _fade(const AudioPlayerScreen(), settings);
      case files:
        return _fade(const FileManagerScreen(), settings);
      case networkStream:
        return _fade(const NetworkStreamScreen(), settings);
      case splash:
      default:
        return _fade(SplashScreen(), settings);
    }
  }

  /// The shell route accepts either an [AppSection] or a shortcut string
  /// ('equalizer', 'vault', 'settings', ...).
  static AppSection _sectionFrom(Object? arguments) {
    if (arguments is AppSection) return arguments;
    if (arguments is String) {
      return switch (arguments) {
        'equalizer' => AppSection.equalizer,
        'vault' => AppSection.vault,
        'settings' => AppSection.settings,
        'folders' => AppSection.folders,
        'library' => AppSection.library,
        'home' => AppSection.home,
        _ => AppSection.folders,
      };
    }
    return AppSection.folders;
  }

  static PageRoute<dynamic> _fade(Widget page, RouteSettings settings) {
    return PageRouteBuilder<dynamic>(
      settings: settings,
      transitionDuration: AppMotion.medium,
      reverseTransitionDuration: AppMotion.fast,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: AppMotion.ease),
          child: child,
        );
      },
    );
  }
}
