import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin, typed wrapper over [SharedPreferences].
class PreferencesService {
  PreferencesService._(this._prefs);

  final SharedPreferences _prefs;

  static Future<PreferencesService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return PreferencesService._(prefs);
  }

  // --- Generic helpers -------------------------------------------------------
  bool getBool(String key, bool fallback) => _prefs.getBool(key) ?? fallback;
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  int getInt(String key, int fallback) => _prefs.getInt(key) ?? fallback;
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  double getDouble(String key, double fallback) =>
      _prefs.getDouble(key) ?? fallback;
  Future<void> setDouble(String key, double value) =>
      _prefs.setDouble(key, value);

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  List<String> getStringList(String key) =>
      _prefs.getStringList(key) ?? [];
  Future<void> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  Future<void> remove(String key) => _prefs.remove(key);

  // --- JSON helpers -----------------------------------------------------------
  List<Map<String, dynamic>> getJsonList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> setJsonList(String key, List<Map<String, dynamic>> value) =>
      _prefs.setString(key, jsonEncode(value));

  Map<String, dynamic> getJsonMap(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  Future<void> setJsonMap(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));
}

/// All preference keys in one place.
abstract final class PrefKeys {
  static const onboardingDone = 'onboarding_done';
  static const libraryIndex = 'library_index_v1';
  static const lastScanTime = 'last_scan_time';
  static const audioIndex = 'audio_index_v1';
  static const audioLastScan = 'audio_last_scan';
  static const recentSearches = 'recent_searches';
  static const playlists = 'playlists_v1';

  // Vault
  static const vaultPinHash = 'vault_pin_hash';
  static const vaultPinSalt = 'vault_pin_salt';
  static const vaultBiometric = 'vault_biometric';
  static const vaultPaths = 'vault_paths';

  // Settings
  static const darkTheme = 'setting_dark_theme';
  static const language = 'setting_language';
  static const defaultSpeed = 'setting_default_speed';
  static const autoResume = 'setting_auto_resume';
  static const backgroundPlayback = 'setting_background_playback';
  static const decoderMode = 'setting_decoder_mode';

  // Gestures
  static const gestureBrightness = 'gesture_brightness';
  static const gestureVolume = 'gesture_volume';
  static const gestureSeek = 'gesture_seek';
  static const gestureDoubleTap = 'gesture_double_tap';
  static const doubleTapSeconds = 'gesture_double_tap_seconds';

  // Subtitle style
  static const subFontSize = 'sub_font_size';
  static const subVerticalPos = 'sub_vertical_pos';
  static const subColor = 'sub_color';
  static const subBackground = 'sub_background';
  static const subOutline = 'sub_outline';
  static const subShadow = 'sub_shadow';

  // Equalizer
  static const eqEnabled = 'eq_enabled';
  static const eqBands = 'eq_bands';
  static const eqPreset = 'eq_preset';
  static const eqMasterGain = 'eq_master_gain';
  static const eqBassBoost = 'eq_bass_boost';
  static const eqVirtualizer = 'eq_virtualizer';
}
