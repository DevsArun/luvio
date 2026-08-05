import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

enum FileSortMode {
  nameAsc('Name (A-Z)'),
  nameDesc('Name (Z-A)'),
  sizeDesc('Size (large first)'),
  sizeAsc('Size (small first)'),
  dateDesc('Newest first'),
  dateAsc('Oldest first'),
  typeAsc('Type');

  const FileSortMode(this.label);
  final String label;
}

enum FileFilter {
  all('All'),
  videos('Videos'),
  audio('Audio'),
  images('Images'),
  documents('Documents'),
  folders('Folders');

  const FileFilter(this.label);
  final String label;
}

/// A single filesystem entry (file or directory) with cheap metadata.
class FileEntry {
  FileEntry({
    required this.path,
    required this.name,
    required this.isDirectory,
    required this.sizeBytes,
    required this.modified,
    this.childCount = 0,
  });

  final String path;
  final String name;
  final bool isDirectory;
  final int sizeBytes;
  final DateTime modified;
  final int childCount;

  bool get isHidden => name.startsWith('.');

  String get extension {
    if (isDirectory) return '';
    final dot = name.lastIndexOf('.');
    if (dot == -1) return '';
    return name.substring(dot + 1).toLowerCase();
  }
}

/// Result of a bulk operation so the UI can report partial failures honestly.
class FileOpResult {
  FileOpResult({this.succeeded = 0, this.failed = 0, this.errors = const []});
  final int succeeded;
  final int failed;
  final List<String> errors;
  bool get hasFailures => failed > 0;
}

/// A trashed item recorded in the app-private recycle bin.
class TrashedEntry {
  TrashedEntry({
    required this.trashedPath,
    required this.originalPath,
    required this.deletedAt,
    required this.sizeBytes,
    required this.isDirectory,
  });

  final String trashedPath;
  final String originalPath;
  final DateTime deletedAt;
  final int sizeBytes;
  final bool isDirectory;

  String get name => originalPath.split('/').last;

  Map<String, dynamic> toJson() => {
        'trashedPath': trashedPath,
        'originalPath': originalPath,
        'deletedAt': deletedAt.toIso8601String(),
        'sizeBytes': sizeBytes,
        'isDirectory': isDirectory,
      };

  static TrashedEntry fromJson(Map<String, dynamic> json) => TrashedEntry(
        trashedPath: json['trashedPath'] as String,
        originalPath: json['originalPath'] as String,
        deletedAt: DateTime.tryParse(json['deletedAt'] as String? ?? '') ??
            DateTime.now(),
        sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
        isDirectory: json['isDirectory'] as bool? ?? false,
      );
}

/// Category totals for the storage analyzer.
class StorageBreakdown {
  StorageBreakdown({
    this.videos = 0,
    this.audio = 0,
    this.images = 0,
    this.documents = 0,
    this.other = 0,
  });

  int videos;
  int audio;
  int images;
  int documents;
  int other;

  int get total => videos + audio + images + documents + other;
}

/// Pure dart:io file operations. No platform channel required, so it works the
/// same on Fire OS as on stock Android within scoped-storage limits.
class FileManagerService {
  static const Set<String> _videoExt = {
    'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm', 'm4v', '3gp', 'ts', 'mpg',
    'mpeg', 'vob', 'ogv', 'divx', 'f4v',
  };
  static const Set<String> _audioExt = {
    'mp3', 'aac', 'm4a', 'flac', 'wav', 'ogg', 'opus', 'wma', 'aiff', 'mka',
    'amr', 'mid',
  };
  static const Set<String> _imageExt = {
    'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'heic', 'heif', 'tiff',
  };
  static const Set<String> _docExt = {
    'pdf', 'doc', 'docx', 'txt', 'rtf', 'xls', 'xlsx', 'ppt', 'pptx', 'epub',
    'srt', 'ass', 'vtt', 'lrc',
  };

  Directory? _trashDir;

  Future<Directory> _trash() async {
    if (_trashDir != null) return _trashDir!;
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/recycle_bin');
    if (!await dir.exists()) await dir.create(recursive: true);
    _trashDir = dir;
    return dir;
  }

  Future<File> _manifestFile() async {
    final t = await _trash();
    return File('${t.path}/.manifest.json');
  }

  Future<List<TrashedEntry>> listTrash() async {
    try {
      final f = await _manifestFile();
      if (!await f.exists()) return [];
      final raw = jsonDecode(await f.readAsString());
      if (raw is! List) return [];
      final items = raw
          .whereType<Map<String, dynamic>>()
          .map(TrashedEntry.fromJson)
          .toList();
      items.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
      return items;
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeManifest(List<TrashedEntry> items) async {
    try {
      final f = await _manifestFile();
      await f.writeAsString(
          jsonEncode(items.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> _removeFromManifest(String trashedPath) async {
    final items = await listTrash();
    items.removeWhere((e) => e.trashedPath == trashedPath);
    await _writeManifest(items);
  }

  FileFilter categoryOf(FileEntry e) {
    if (e.isDirectory) return FileFilter.folders;
    final ext = e.extension;
    if (_videoExt.contains(ext)) return FileFilter.videos;
    if (_audioExt.contains(ext)) return FileFilter.audio;
    if (_imageExt.contains(ext)) return FileFilter.images;
    if (_docExt.contains(ext)) return FileFilter.documents;
    return FileFilter.all;
  }

  /// Lists the immediate children of [path]. Never throws; returns [] on error.
  Future<List<FileEntry>> list(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];
    final out = <FileEntry>[];
    try {
      await for (final entity in dir.list(followLinks: false)) {
        try {
          final stat = await entity.stat();
          final name = entity.path.split('/').last;
          if (entity is Directory) {
            var count = 0;
            try {
              count = await entity.list(followLinks: false).length;
            } catch (_) {}
            out.add(FileEntry(
              path: entity.path,
              name: name,
              isDirectory: true,
              sizeBytes: 0,
              modified: stat.modified,
              childCount: count,
            ));
          } else {
            out.add(FileEntry(
              path: entity.path,
              name: name,
              isDirectory: false,
              sizeBytes: stat.size,
              modified: stat.modified,
            ));
          }
        } catch (_) {}
      }
    } catch (_) {}
    return out;
  }

  List<FileEntry> sortAndFilter(
    List<FileEntry> entries, {
    required FileSortMode sort,
    required FileFilter filter,
    bool showHidden = false,
    String query = '',
  }) {
    var list = entries.where((e) {
      if (!showHidden && e.isHidden) return false;
      if (query.isNotEmpty &&
          !e.name.toLowerCase().contains(query.toLowerCase())) {
        return false;
      }
      if (filter == FileFilter.all) return true;
      return categoryOf(e) == filter;
    }).toList();

    // Folders always float to the top, then apply the chosen order.
    int cmp(FileEntry a, FileEntry b) {
      switch (sort) {
        case FileSortMode.nameAsc:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case FileSortMode.nameDesc:
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case FileSortMode.sizeDesc:
          return b.sizeBytes.compareTo(a.sizeBytes);
        case FileSortMode.sizeAsc:
          return a.sizeBytes.compareTo(b.sizeBytes);
        case FileSortMode.dateDesc:
          return b.modified.compareTo(a.modified);
        case FileSortMode.dateAsc:
          return a.modified.compareTo(b.modified);
        case FileSortMode.typeAsc:
          return a.extension.compareTo(b.extension);
      }
    }

    list.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return cmp(a, b);
    });
    return list;
  }

  Future<FileOpResult> rename(String path, String newName) async {
    try {
      final parent = path.substring(0, path.lastIndexOf('/'));
      final target = '$parent/$newName';
      if (await FileSystemEntity.isDirectory(path)) {
        await Directory(path).rename(target);
      } else {
        await File(path).rename(target);
      }
      return FileOpResult(succeeded: 1);
    } catch (e) {
      return FileOpResult(failed: 1, errors: ['$e']);
    }
  }

  Future<FileOpResult> copy(List<String> paths, String destDir) async {
    var ok = 0, fail = 0;
    final errors = <String>[];
    for (final p in paths) {
      try {
        await _copyEntity(p, '$destDir/${p.split('/').last}');
        ok++;
      } catch (e) {
        fail++;
        errors.add('${p.split('/').last}: $e');
      }
    }
    return FileOpResult(succeeded: ok, failed: fail, errors: errors);
  }

  Future<FileOpResult> move(List<String> paths, String destDir) async {
    var ok = 0, fail = 0;
    final errors = <String>[];
    for (final p in paths) {
      final dest = '$destDir/${p.split('/').last}';
      try {
        if (await FileSystemEntity.isDirectory(p)) {
          await Directory(p).rename(dest);
        } else {
          await File(p).rename(dest);
        }
        ok++;
      } catch (_) {
        // Cross-volume rename fails; fall back to copy+delete.
        try {
          await _copyEntity(p, dest);
          await _deleteEntity(p);
          ok++;
        } catch (e) {
          fail++;
          errors.add('${p.split('/').last}: $e');
        }
      }
    }
    return FileOpResult(succeeded: ok, failed: fail, errors: errors);
  }

  Future<void> _copyEntity(String src, String dest) async {
    if (await FileSystemEntity.isDirectory(src)) {
      final destDir = Directory(dest);
      await destDir.create(recursive: true);
      await for (final entity in Directory(src).list(followLinks: false)) {
        await _copyEntity(entity.path, '$dest/${entity.path.split('/').last}');
      }
    } else {
      await File(src).copy(dest);
    }
  }

  Future<void> _deleteEntity(String path) async {
    if (await FileSystemEntity.isDirectory(path)) {
      await Directory(path).delete(recursive: true);
    } else {
      await File(path).delete();
    }
  }

  /// Soft-delete: move into the app-private recycle bin. Returns records that
  /// callers should persist via PreferencesService.
  Future<List<TrashedEntry>> moveToTrash(List<String> paths) async {
    final trash = await _trash();
    final records = <TrashedEntry>[];
    for (final p in paths) {
      try {
        final stamp = DateTime.now().millisecondsSinceEpoch;
        final name = p.split('/').last;
        final dest = '${trash.path}/${stamp}_$name';
        final isDir = await FileSystemEntity.isDirectory(p);
        final size = isDir ? await _dirSize(Directory(p)) : await File(p).length();
        if (isDir) {
          await Directory(p).rename(dest);
        } else {
          await File(p).rename(dest);
        }
        records.add(TrashedEntry(
          trashedPath: dest,
          originalPath: p,
          deletedAt: DateTime.now(),
          sizeBytes: size,
          isDirectory: isDir,
        ));
      } catch (_) {}
    }
    if (records.isNotEmpty) {
      final existing = await listTrash();
      await _writeManifest([...records, ...existing]);
    }
    return records;
  }

  Future<bool> restore(TrashedEntry entry) async {
    try {
      if (entry.isDirectory) {
        await Directory(entry.trashedPath).rename(entry.originalPath);
      } else {
        await File(entry.trashedPath).rename(entry.originalPath);
      }
      await _removeFromManifest(entry.trashedPath);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> deleteForever(TrashedEntry entry) async {
    try {
      await _deleteEntity(entry.trashedPath);
    } catch (_) {}
    await _removeFromManifest(entry.trashedPath);
  }

  Future<void> emptyTrash() async {
    final items = await listTrash();
    for (final e in items) {
      try {
        await _deleteEntity(e.trashedPath);
      } catch (_) {}
    }
    await _writeManifest([]);
  }

  Future<void> deletePermanently(List<String> paths) async {
    for (final p in paths) {
      try {
        await _deleteEntity(p);
      } catch (_) {}
    }
  }

  /// Hide a folder by dropping a `.nomedia` marker so media scanners skip it.
  Future<bool> toggleNoMedia(String dirPath, bool hide) async {
    try {
      final marker = File('$dirPath/.nomedia');
      if (hide) {
        if (!await marker.exists()) await marker.create();
      } else {
        if (await marker.exists()) await marker.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<StorageBreakdown> analyze(String path) async {
    final b = StorageBreakdown();
    final dir = Directory(path);
    if (!await dir.exists()) return b;
    try {
      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        int size;
        try {
          size = await entity.length();
        } catch (_) {
          continue;
        }
        final name = entity.path.split('/').last;
        final dot = name.lastIndexOf('.');
        final ext = dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
        if (_videoExt.contains(ext)) {
          b.videos += size;
        } else if (_audioExt.contains(ext)) {
          b.audio += size;
        } else if (_imageExt.contains(ext)) {
          b.images += size;
        } else if (_docExt.contains(ext)) {
          b.documents += size;
        } else {
          b.other += size;
        }
      }
    } catch (_) {}
    return b;
  }

  Future<int> _dirSize(Directory dir) async {
    var total = 0;
    try {
      await for (final e in dir.list(recursive: true, followLinks: false)) {
        if (e is File) {
          try {
            total += await e.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }
}
