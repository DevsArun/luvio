import 'package:flutter/material.dart';

import '../models/app_enums.dart';
import '../services/preferences_service.dart';

/// Application-wide user preferences (theme, language, playback, gestures,
/// subtitle appearance, equalizer). All values persist across launches.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._prefs) {
    _load();
  }

  final PreferencesService _prefs;

  // --- General ---------------------------------------------------------------
  bool darkTheme = true;
  AppLanguage language = AppLanguage.system;

  // --- Playback --------------------------------------------------------------
  double defaultSpeed = 1.0;
  bool autoResume = true;
  bool backgroundPlayback = false;
  DecoderMode decoderMode = DecoderMode.hardwarePlus;

  // --- Gestures --------------------------------------------------------------
  bool gestureBrightness = true;
  bool gestureVolume = true;
  bool gestureSeek = true;
  bool gestureDoubleTap = true;
  int doubleTapSeconds = 10;

  // --- Subtitle appearance ----------------------------------------------------
  double subtitleFontSize = 24;
  double subtitleVerticalPosition = 0.85; // fraction from top
  int subtitleColorValue = 0xFFFFFFFF;

  /// UI-facing view of the subtitle text color.
  Color get subtitleColor => Color(subtitleColorValue);
  SubtitleBackground subtitleBackground = SubtitleBackground.translucent;
  SubtitleOutline subtitleOutline = SubtitleOutline.normal;
  SubtitleShadow subtitleShadow = SubtitleShadow.subtle;

  // --- Equalizer ---------------------------------------------------------------
  bool eqEnabled = false;
  List<double> eqBands = List.filled(10, 0);
  EqPreset eqPreset = EqPreset.custom;
  double eqMasterGain = 0.75; // 0..1 dial
  double eqBassBoost = 0.4; // 0..1
  double eqVirtualizer = 0.6; // 0..1

  void _load() {
    darkTheme = _prefs.getBool(PrefKeys.darkTheme, true);
    language = AppLanguage.values[_prefs
        .getInt(PrefKeys.language, AppLanguage.system.index)
        .clamp(0, AppLanguage.values.length - 1)];
    defaultSpeed = _prefs.getDouble(PrefKeys.defaultSpeed, 1.0);
    autoResume = _prefs.getBool(PrefKeys.autoResume, true);
    backgroundPlayback = _prefs.getBool(PrefKeys.backgroundPlayback, false);
    decoderMode = DecoderMode.values[_prefs
        .getInt(PrefKeys.decoderMode, DecoderMode.hardwarePlus.index)
        .clamp(0, DecoderMode.values.length - 1)];

    gestureBrightness = _prefs.getBool(PrefKeys.gestureBrightness, true);
    gestureVolume = _prefs.getBool(PrefKeys.gestureVolume, true);
    gestureSeek = _prefs.getBool(PrefKeys.gestureSeek, true);
    gestureDoubleTap = _prefs.getBool(PrefKeys.gestureDoubleTap, true);
    doubleTapSeconds = _prefs.getInt(PrefKeys.doubleTapSeconds, 10);

    subtitleFontSize = _prefs.getDouble(PrefKeys.subFontSize, 24);
    subtitleVerticalPosition = _prefs.getDouble(PrefKeys.subVerticalPos, 0.85);
    subtitleColorValue = _prefs.getInt(PrefKeys.subColor, 0xFFFFFFFF);
    subtitleBackground = SubtitleBackground.values[_prefs
        .getInt(PrefKeys.subBackground, SubtitleBackground.translucent.index)
        .clamp(0, SubtitleBackground.values.length - 1)];
    subtitleOutline = SubtitleOutline.values[_prefs
        .getInt(PrefKeys.subOutline, SubtitleOutline.normal.index)
        .clamp(0, SubtitleOutline.values.length - 1)];
    subtitleShadow = SubtitleShadow.values[_prefs
        .getInt(PrefKeys.subShadow, SubtitleShadow.subtle.index)
        .clamp(0, SubtitleShadow.values.length - 1)];

    eqEnabled = _prefs.getBool(PrefKeys.eqEnabled, false);
    final bands = _prefs.getStringList(PrefKeys.eqBands);
    if (bands.length == 10) {
      eqBands = bands.map((b) => double.tryParse(b) ?? 0.0).toList();
    }
    eqPreset = EqPreset.values[_prefs
        .getInt(PrefKeys.eqPreset, EqPreset.custom.index)
        .clamp(0, EqPreset.values.length - 1)];
    eqMasterGain = _prefs.getDouble(PrefKeys.eqMasterGain, 0.75);
    eqBassBoost = _prefs.getDouble(PrefKeys.eqBassBoost, 0.4);
    eqVirtualizer = _prefs.getDouble(PrefKeys.eqVirtualizer, 0.6);
  }

  // --- Setters ------------------------------------------------------------------
  void setDarkTheme(bool value) {
    darkTheme = value;
    _prefs.setBool(PrefKeys.darkTheme, value);
    notifyListeners();
  }

  void setLanguage(AppLanguage value) {
    language = value;
    _prefs.setInt(PrefKeys.language, value.index);
    notifyListeners();
  }

  void setDefaultSpeed(double value) {
    defaultSpeed = value;
    _prefs.setDouble(PrefKeys.defaultSpeed, value);
    notifyListeners();
  }

  void setAutoResume(bool value) {
    autoResume = value;
    _prefs.setBool(PrefKeys.autoResume, value);
    notifyListeners();
  }

  void setBackgroundPlayback(bool value) {
    backgroundPlayback = value;
    _prefs.setBool(PrefKeys.backgroundPlayback, value);
    notifyListeners();
  }

  void setDecoderMode(DecoderMode value) {
    decoderMode = value;
    _prefs.setInt(PrefKeys.decoderMode, value.index);
    notifyListeners();
  }

  void setGestureBrightness(bool value) {
    gestureBrightness = value;
    _prefs.setBool(PrefKeys.gestureBrightness, value);
    notifyListeners();
  }

  void setGestureVolume(bool value) {
    gestureVolume = value;
    _prefs.setBool(PrefKeys.gestureVolume, value);
    notifyListeners();
  }

  void setGestureSeek(bool value) {
    gestureSeek = value;
    _prefs.setBool(PrefKeys.gestureSeek, value);
    notifyListeners();
  }

  void setGestureDoubleTap(bool value) {
    gestureDoubleTap = value;
    _prefs.setBool(PrefKeys.gestureDoubleTap, value);
    notifyListeners();
  }

  void setDoubleTapSeconds(int value) {
    doubleTapSeconds = value;
    _prefs.setInt(PrefKeys.doubleTapSeconds, value);
    notifyListeners();
  }

  void setSubtitleFontSize(double value) {
    subtitleFontSize = value;
    _prefs.setDouble(PrefKeys.subFontSize, value);
    notifyListeners();
  }

  void setSubtitleVerticalPosition(double value) {
    subtitleVerticalPosition = value;
    _prefs.setDouble(PrefKeys.subVerticalPos, value);
    notifyListeners();
  }

  void setSubtitleColor(Color value) {
    subtitleColorValue = value.value;
    _prefs.setInt(PrefKeys.subColor, value.value);
    notifyListeners();
  }

  void setSubtitleBackground(SubtitleBackground value) {
    subtitleBackground = value;
    _prefs.setInt(PrefKeys.subBackground, value.index);
    notifyListeners();
  }

  void setSubtitleOutline(SubtitleOutline value) {
    subtitleOutline = value;
    _prefs.setInt(PrefKeys.subOutline, value.index);
    notifyListeners();
  }

  void setSubtitleShadow(SubtitleShadow value) {
    subtitleShadow = value;
    _prefs.setInt(PrefKeys.subShadow, value.index);
    notifyListeners();
  }

  Future<void> setEqEnabled(bool value) async {
    eqEnabled = value;
    _prefs.setBool(PrefKeys.eqEnabled, value);
    notifyListeners();
  }

  Future<void> setEqBand(int index, double value) async {
    eqBands[index] = value.clamp(-15.0, 15.0);
    eqPreset = EqPreset.custom;
    _persistEq();
    notifyListeners();
  }

  Future<void> applyEqPreset(EqPreset preset) async {
    eqPreset = preset;
    if (preset != EqPreset.custom) {
      eqBands = preset.gains.map((g) => g.toDouble()).toList();
    }
    _persistEq();
    notifyListeners();
  }

  void resetEq() {
    eqBands = List.filled(10, 0);
    eqPreset = EqPreset.custom;
    _persistEq();
    notifyListeners();
  }

  Future<void> setEqMasterGain(double value) async {
    eqMasterGain = value.clamp(0.0, 1.0);
    _prefs.setDouble(PrefKeys.eqMasterGain, eqMasterGain);
    notifyListeners();
  }

  Future<void> setEqBassBoost(double value) async {
    eqBassBoost = value.clamp(0.0, 1.0);
    _prefs.setDouble(PrefKeys.eqBassBoost, eqBassBoost);
    notifyListeners();
  }

  Future<void> setEqVirtualizer(double value) async {
    eqVirtualizer = value.clamp(0.0, 1.0);
    _prefs.setDouble(PrefKeys.eqVirtualizer, eqVirtualizer);
    notifyListeners();
  }

  void _persistEq() {
    _prefs.setStringList(
      PrefKeys.eqBands,
      eqBands.map((b) => b.toString()).toList(),
    );
    _prefs.setInt(PrefKeys.eqPreset, eqPreset.index);
  }

  // --- Onboarding -----------------------------------------------------------------
  bool get onboardingDone => _prefs.getBool(PrefKeys.onboardingDone, false);

  Future<void> setOnboardingDone([bool value = true]) =>
      _prefs.setBool(PrefKeys.onboardingDone, value);

  // --- Canonical aliases used across the UI layer ----------------------------
  bool get brightnessGesture => gestureBrightness;
  bool get volumeGesture => gestureVolume;
  bool get seekGesture => gestureSeek;
  bool get doubleTapGesture => gestureDoubleTap;
  void setBrightnessGesture(bool value) => setGestureBrightness(value);
  void setVolumeGesture(bool value) => setGestureVolume(value);
  void setSeekGesture(bool value) => setGestureSeek(value);
  void setDoubleTapGesture(bool value) => setGestureDoubleTap(value);

  double get subtitleVerticalPos => subtitleVerticalPosition;
  void setSubtitleVerticalPos(double value) =>
      setSubtitleVerticalPosition(value);

  Future<void> resetEqBands() async => resetEq();
}
