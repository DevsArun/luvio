import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/developer_options.dart';

/// Persists [DeveloperOptions] as JSON in SharedPreferences so the Developer
/// Options screen and the player engine can share the same live values.
class DeveloperOptionsStore {
  static const String key = 'setting_dev_options_v1';

  Future<DeveloperOptions> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return const DeveloperOptions();
    try {
      return DeveloperOptions.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const DeveloperOptions();
    }
  }

  Future<void> save(DeveloperOptions options) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(options.toJson()));
  }
}
