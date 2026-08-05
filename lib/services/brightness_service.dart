import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';

/// Controls the player's screen brightness.
///
/// The `screen_brightness` plugin silently fails on several Android / Fire OS
/// builds (the future resolves but the panel never changes), which is why the
/// brightness slide gesture did nothing. So the native window attribute is
/// tried first — that is the same approach MX Player uses and it needs no
/// runtime permission because it only affects our own window — and the plugin
/// is kept purely as a fallback.
class BrightnessService {
  BrightnessService._();
  static final BrightnessService instance = BrightnessService._();
  factory BrightnessService() => instance;

  static const MethodChannel _channel = MethodChannel('luvio_player/screen');

  /// Whether the native path is usable. Set on the first successful call so we
  /// do not keep paying for a failing platform round-trip on every drag frame.
  bool _nativeWorks = true;

  /// Current brightness in the 0.0 – 1.0 range.
  Future<double> current() async {
    if (_nativeWorks) {
      try {
        final value = await _channel.invokeMethod<double>('getBrightness');
        if (value != null && value >= 0 && value <= 1) return value;
      } catch (_) {
        _nativeWorks = false;
      }
    }
    try {
      return await ScreenBrightness().current;
    } catch (_) {
      return 0.5;
    }
  }

  /// Applies [value] (0.0 – 1.0). Returns true when the screen actually changed.
  Future<bool> set(double value) async {
    final clamped = value.clamp(0.0, 1.0).toDouble();
    if (_nativeWorks) {
      try {
        final ok = await _channel
            .invokeMethod<bool>('setBrightness', {'value': clamped});
        if (ok == true) return true;
        _nativeWorks = false;
      } catch (_) {
        _nativeWorks = false;
      }
    }
    try {
      await ScreenBrightness().setScreenBrightness(clamped);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Hands brightness control back to the system when the player closes.
  Future<void> reset() async {
    if (_nativeWorks) {
      try {
        await _channel.invokeMethod<bool>('resetBrightness');
        return;
      } catch (_) {
        _nativeWorks = false;
      }
    }
    try {
      await ScreenBrightness().resetScreenBrightness();
    } catch (_) {}
  }
}