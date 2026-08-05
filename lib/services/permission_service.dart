import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Requests the storage permission appropriate for the device's SDK level
/// (Fire OS is Android-based: Fire OS 7 ≈ API 28, Fire OS 8 ≈ API 30+).
class PermissionService {
  static const MethodChannel _channel = MethodChannel('luvio_player/storage');

  Future<bool> hasMediaPermission() async {
    if (await hasAllFilesAccess()) return true;
    final sdk = await _sdkInt();
    if (sdk >= 33) {
      final video = await Permission.videos.status;
      return video.isGranted;
    }
    final storage = await Permission.storage.status;
    return storage.isGranted;
  }

  /// Requests read access to the user's media.
  ///
  /// Android 13+ splits storage into per-type grants, so we ask for video AND
  /// audio (the app has a music player too). Granting either one is enough to
  /// start scanning — we don't block the user on the audio grant.
  Future<bool> requestMediaPermission() async {
    if (await hasAllFilesAccess()) return true;

    final sdk = await _sdkInt();
    if (sdk >= 33) {
      final video = await Permission.videos.request();
      // Best-effort; a refusal here must not block the video library.
      try {
        await Permission.audio.request();
      } catch (_) {}
      return video.isGranted;
    }
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  /// True when the user granted Android's "All files access".
  ///
  /// Not required for scanning (MediaStore covers that), but it is what makes
  /// Delete and Rename work on files the app does not own.
  Future<bool> hasAllFilesAccess() async {
    try {
      return await _channel.invokeMethod<bool>('hasAllFilesAccess') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system "All files access" settings screen.
  Future<bool> requestAllFilesAccess() async {
    try {
      return await _channel.invokeMethod<bool>('requestAllFilesAccess') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Android 13+ needs an explicit grant before the lockscreen / notification
  /// media controls can appear. Best-effort: older devices always return true.
  Future<bool> requestNotificationPermission() async {
    try {
      final sdk = await _sdkInt();
      if (sdk < 33) return true;
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openSettings() => openAppSettings();

  Future<int> _sdkInt() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.version.sdkInt;
    } catch (_) {
      return 33;
    }
  }
}
