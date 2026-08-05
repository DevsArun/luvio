import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackupResult {
  BackupResult({required this.success, required this.message, this.path});
  final bool success;
  final String message;
  final String? path;
}

/// Part 7 — Backup & Restore. Serializes every SharedPreferences key
/// (settings, indexes, playlists, gesture/subtitle prefs) into a portable
/// JSON file the user can save or share, and restores it back.
class BackupService {
  static const int _version = 1;

  Future<BackupResult> export() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = <String, dynamic>{};
      for (final key in prefs.getKeys()) {
        final v = prefs.get(key);
        if (v is bool) {
          data[key] = {'t': 'b', 'v': v};
        } else if (v is int) {
          data[key] = {'t': 'i', 'v': v};
        } else if (v is double) {
          data[key] = {'t': 'd', 'v': v};
        } else if (v is String) {
          data[key] = {'t': 's', 'v': v};
        } else if (v is List<String>) {
          data[key] = {'t': 'l', 'v': v};
        }
      }
      final payload = jsonEncode({
        'app': 'luvio_player',
        'version': _version,
        'exportedAt': DateTime.now().toIso8601String(),
        'prefs': data,
      });
      final tmp = await getTemporaryDirectory();
      final name = 'luvio_backup_${DateTime.now().millisecondsSinceEpoch}.json';
      final file = File('${tmp.path}/$name');
      await file.writeAsString(payload);
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Luvio backup',
        fileName: name,
        bytes: await file.readAsBytes(),
      );
      return BackupResult(
        success: true,
        message: 'Backup exported (${data.length} keys)',
        path: saved ?? file.path,
      );
    } catch (e) {
      return BackupResult(success: false, message: 'Export failed: $e');
    }
  }

  Future<BackupResult> import() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (res == null || res.files.isEmpty) {
        return BackupResult(success: false, message: 'No file selected');
      }
      final path = res.files.single.path;
      if (path == null) {
        return BackupResult(success: false, message: 'File path unavailable');
      }
      final raw = jsonDecode(await File(path).readAsString());
      if (raw is! Map || raw['prefs'] is! Map) {
        return BackupResult(success: false, message: 'Invalid backup file');
      }
      final prefs = await SharedPreferences.getInstance();
      final data = raw['prefs'] as Map;
      var count = 0;
      for (final entry in data.entries) {
        final key = entry.key.toString();
        final rec = entry.value;
        if (rec is! Map) continue;
        final t = rec['t'];
        final v = rec['v'];
        try {
          switch (t) {
            case 'b':
              await prefs.setBool(key, v == true);
              break;
            case 'i':
              await prefs.setInt(key, (v as num).toInt());
              break;
            case 'd':
              await prefs.setDouble(key, (v as num).toDouble());
              break;
            case 's':
              await prefs.setString(key, '$v');
              break;
            case 'l':
              await prefs.setStringList(
                  key, (v as List).map((e) => '$e').toList());
              break;
          }
          count++;
        } catch (_) {}
      }
      return BackupResult(
        success: true,
        message: 'Restored $count settings. Restart the app to apply.',
      );
    } catch (e) {
      return BackupResult(success: false, message: 'Import failed: $e');
    }
  }
}
