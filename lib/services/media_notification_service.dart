import 'dart:io';

import 'package:flutter/services.dart';

/// Lockscreen / notification-shade media controls.
///
/// Thin Dart wrapper over the native `MediaNotificationService` foreground
/// service. Every call is best-effort: if the platform side is unavailable
/// (non-Android, or notifications blocked) the calls quietly no-op so playback
/// is never affected.
class MediaNotificationService {
  MediaNotificationService._();

  static final MediaNotificationService instance = MediaNotificationService._();

  static const MethodChannel _channel =
      MethodChannel('luvio_player/media_notification');

  bool _handlerAttached = false;
  bool _visible = false;

  /// True while a media notification is on screen.
  bool get visible => _visible;

  /// Called with one of: playPause, next, previous, rewind, forward, stop.
  /// Seek requests arrive through [onSeek].
  void Function(String action)? onAction;

  /// Called when the lockscreen scrubber is dragged (milliseconds).
  void Function(int positionMs)? onSeek;

  bool get _supported => Platform.isAndroid;

  void _attachHandler() {
    if (_handlerAttached) return;
    _handlerAttached = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'action') return null;
      final raw = call.arguments;
      if (raw is! String) return null;

      if (raw.startsWith('seek:')) {
        final ms = int.tryParse(raw.substring(5));
        if (ms != null) onSeek?.call(ms);
        return null;
      }

      const map = <String, String>{
        'dev.luvio.player.PLAY_PAUSE': 'playPause',
        'dev.luvio.player.NEXT': 'next',
        'dev.luvio.player.PREVIOUS': 'previous',
        'dev.luvio.player.REWIND': 'rewind',
        'dev.luvio.player.FORWARD': 'forward',
        'dev.luvio.player.STOP': 'stop',
      };
      final action = map[raw];
      if (action != null) onAction?.call(action);
      return null;
    });
  }

  /// Shows or refreshes the media notification.
  Future<void> show({
    required String title,
    required String subtitle,
    required bool playing,
    required Duration position,
    required Duration duration,
    bool hasNext = false,
    bool hasPrevious = false,
  }) async {
    if (!_supported) return;
    _attachHandler();
    try {
      await _channel.invokeMethod<bool>('show', <String, dynamic>{
        'title': title,
        'subtitle': subtitle,
        'playing': playing,
        'position': position.inMilliseconds,
        'duration': duration.inMilliseconds,
        'hasNext': hasNext,
        'hasPrevious': hasPrevious,
      });
      _visible = true;
    } catch (_) {
      // Notification is a nice-to-have; never surface an error here.
    }
  }

  /// Removes the media notification and stops the foreground service.
  Future<void> hide() async {
    if (!_supported || !_visible) return;
    _visible = false;
    try {
      await _channel.invokeMethod<bool>('hide');
    } catch (_) {
      // Ignore.
    }
  }
}
