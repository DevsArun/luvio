import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/mime_types.dart';

import '../../core/theme/app_colors.dart';
import '../../services/file_manager_service.dart';
import 'recycle_bin_screen.dart';

/// Full offline file manager: navigation, multi-select, copy/move, rename,
/// delete (to recycle bin), share, hide, sort/filter/search, storage analyzer.
class FileManagerScreen extends StatefulWidget {
  const FileManagerScreen({super.key, this.initialPath});

  final String? initialPath;

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  final FileManagerService _svc = FileManagerService();

  static const String _root = '/storage/emulated/0';

  late String _current;
  List<FileEntry> _all = [];
  bool _loading = true;

  FileSortMode _sort = FileSortMode.nameAsc;
  FileFilter _filter = FileFilter.all;
  bool _showHidden = false;
  String _query = '';
  bool _searching = false;

  final Set<String> _selected = {};
  bool get _selecting => _selected.isNotEmpty;

  // Clipboard for copy/move (paste flow).
  List<String> _clipboard = [];
  bool _clipboardMove = false;

  @override
  void initState() {
    super.initState();
    _current = widget.initialPath ?? _root;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await _svc.list(_current);
    if (!mounted) return;
    setState(() {
      _all = entries;
      _loading = false;
      _selected.clear();
    });
  }

  List<FileEntry> get _visible => _svc.sortAndFilter(
        _all,
        sort: _sort,
        filter: _filter,
        showHidden: _showHidden,
        query: _query,
      );

  void _open(FileEntry e) {
    if (_selecting) {
      _toggleSelect(e);
      return;
    }
    if (e.isDirectory) {
      setState(() {
        _current = e.path;
        _query = '';
        _searching = false;
      });
      _load();
    } else {
      _showFileActions(e);
    }
  }

  void _toggleSelect(FileEntry e) {
    setState(() {
      if (!_selected.add(e.path)) _selected.remove(e.path);
    });
  }

  bool _canGoUp() => _current != _root && _current.contains('/');

  void _goUp() {
    if (!_canGoUp()) return;
    setState(() {
      _current = _current.substring(0, _current.lastIndexOf('/'));
      if (_current.isEmpty) _current = '/';
      _query = '';
      _searching = false;
    });
    _load();
  }

  Future<void> _snack(String msg) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---- Actions ----

  Future<void> _deleteSelected() async {
    final paths = _selected.toList();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Move to Recycle Bin?'),
        content: Text('${paths.length} item(s) will be moved to the recycle '
            'bin. You can restore them later.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Move')),
        ],
      ),
    );
    if (confirm != true) return;
    await _svc.moveToTrash(paths);
    await _snack('Moved ${paths.length} item(s) to recycle bin');
    await _load();
  }

  Future<void> _renameSelected() async {
    if (_selected.length != 1) return;
    final path = _selected.first;
    final oldName = path.split('/').last;
    final ctrl = TextEditingController(text: oldName);
    final newName = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctrl.text.trim()),
              child: const Text('Rename')),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == oldName) return;
    final res = await _svc.rename(path, newName);
    await _snack(res.hasFailures ? 'Rename failed' : 'Renamed');
    await _load();
  }

  Future<void> _shareSelected() async {
    final files = _selected
        .where((p) => FileSystemEntity.typeSync(p) == FileSystemEntityType.file)
        .map((p) => XFile(p,
            mimeType: mimeTypeForPath(p), name: p.split('/').last))
        .toList();
    if (files.isEmpty) {
      await _snack('Select files to share (folders cannot be shared directly)');
      return;
    }
    try {
      await Share.shareXFiles(files);
    } catch (e) {
      await _snack('Share failed: $e');
    }
  }

  void _copySelected({required bool move}) {
    setState(() {
      _clipboard = _selected.toList();
      _clipboardMove = move;
      _selected.clear();
    });
    _snack('${_clipboard.length} item(s) ready to '
        '${move ? 'move' : 'copy'}. Open a folder and tap Paste.');
  }

  Future<void> _paste() async {
    if (_clipboard.isEmpty) return;
    final res = _clipboardMove
        ? await _svc.move(_clipboard, _current)
        : await _svc.copy(_clipboard, _current);
    await _snack(res.hasFailures
        ? 'Done with ${res.failed} error(s)'
        : '${res.succeeded} item(s) pasted');
    setState(() => _clipboard = []);
    await _load();
  }

  Future<void> _showFileActions(FileEntry e) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surfaceContainerHigh,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(_iconFor(e)),
              title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(_subtitle(e)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(c);
                _selected
                  ..clear()
                  ..add(e.path);
                _shareSelected();
                _selected.clear();
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(c);
                _selected
                  ..clear()
                  ..add(e.path);
                _renameSelected().then((_) => _selected.clear());
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(c);
                _selected
                  ..clear()
                  ..add(e.path);
                _copySelected(move: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: const Text('Move'),
              onTap: () {
                Navigator.pop(c);
                _selected
                  ..clear()
                  ..add(e.path);
                _copySelected(move: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('File info'),
              onTap: () {
                Navigator.pop(c);
                _showInfo(e);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(c);
                _selected
                  ..clear()
                  ..add(e.path);
                _deleteSelected();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showInfo(FileEntry e) async {
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('File information'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoRow('Name', e.name),
            _infoRow('Path', e.path),
            _infoRow('Type', e.isDirectory ? 'Folder' : e.extension.toUpperCase()),
            if (!e.isDirectory) _infoRow('Size', _bytes(e.sizeBytes)),
            if (e.isDirectory) _infoRow('Items', '${e.childCount}'),
            _infoRow('Modified', e.modified.toString().split('.').first),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _analyzeStorage() async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );
    final b = await _svc.analyze(_current);
    if (!mounted) return;
    Navigator.pop(context);
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Storage analyzer'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoRow('Videos', _bytes(b.videos)),
            _infoRow('Audio', _bytes(b.audio)),
            _infoRow('Images', _bytes(b.images)),
            _infoRow('Documents', _bytes(b.documents)),
            _infoRow('Other', _bytes(b.other)),
            const Divider(),
            _infoRow('Total', _bytes(b.total)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Close')),
        ],
      ),
    );
  }

  // ---- Helpers ----

  Widget _infoRow(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 90,
                child: Text(k,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(child: Text(v)),
          ],
        ),
      );

  String _subtitle(FileEntry e) => e.isDirectory
      ? '${e.childCount} items'
      : '${_bytes(e.sizeBytes)} · ${e.modified.toString().split(' ').first}';

  IconData _iconFor(FileEntry e) {
    if (e.isDirectory) return Icons.folder;
    switch (_svc.categoryOf(e)) {
      case FileFilter.videos:
        return Icons.movie_outlined;
      case FileFilter.audio:
        return Icons.music_note_outlined;
      case FileFilter.images:
        return Icons.image_outlined;
      case FileFilter.documents:
        return Icons.description_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  String _bytes(int b) {
    if (b <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var size = b.toDouble();
    var i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_selecting) {
          setState(_selected.clear);
          return false;
        }
        if (_canGoUp()) {
          _goUp();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        floatingActionButton: _clipboard.isNotEmpty
            ? FloatingActionButton.extended(
                onPressed: _paste,
                icon: const Icon(Icons.content_paste),
                label: Text('Paste (${_clipboard.length})'),
              )
            : null,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _breadcrumb(),
                  _filterChips(),
                  Expanded(child: _list()),
                ],
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (_selecting) {
      return AppBar(
        backgroundColor: AppColors.surfaceContainerHigh,
        leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => setState(_selected.clear)),
        title: Text('${_selected.length} selected'),
        actions: [
          if (_selected.length == 1)
            IconButton(
                icon: const Icon(Icons.drive_file_rename_outline),
                onPressed: _renameSelected),
          IconButton(icon: const Icon(Icons.ios_share), onPressed: _shareSelected),
          IconButton(
              icon: const Icon(Icons.content_copy),
              onPressed: () => _copySelected(move: false)),
          IconButton(
              icon: const Icon(Icons.drive_file_move_outline),
              onPressed: () => _copySelected(move: true)),
          IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteSelected),
        ],
      );
    }
    if (_searching) {
      return AppBar(
        backgroundColor: AppColors.surfaceContainerHigh,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() {
                  _searching = false;
                  _query = '';
                })),
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
              hintText: 'Search in this folder', border: InputBorder.none),
          onChanged: (v) => setState(() => _query = v),
        ),
      );
    }
    return AppBar(
      backgroundColor: AppColors.surfaceContainerHigh,
      leading: _canGoUp()
          ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _goUp)
          : null,
      title: const Text('File Manager'),
      actions: [
        IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => setState(() => _searching = true)),
        PopupMenuButton<FileSortMode>(
          icon: const Icon(Icons.sort),
          onSelected: (v) => setState(() => _sort = v),
          itemBuilder: (c) => FileSortMode.values
              .map((m) => PopupMenuItem(value: m, child: Text(m.label)))
              .toList(),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (v) {
            switch (v) {
              case 'hidden':
                setState(() => _showHidden = !_showHidden);
                break;
              case 'analyze':
                _analyzeStorage();
                break;
              case 'trash':
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const RecycleBinScreen()));
                break;
            }
          },
          itemBuilder: (c) => [
            CheckedPopupMenuItem(
                value: 'hidden',
                checked: _showHidden,
                child: const Text('Show hidden')),
            const PopupMenuItem(
                value: 'analyze', child: Text('Storage analyzer')),
            const PopupMenuItem(value: 'trash', child: Text('Recycle bin')),
          ],
        ),
      ],
    );
  }

  Widget _breadcrumb() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: AppColors.surfaceContainerLow,
        child: Text(
          _current.replaceFirst('/storage/emulated/0', 'Internal storage'),
          style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );

  Widget _filterChips() => SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: FileFilter.values
              .map((f) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(f.label),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ))
              .toList(),
        ),
      );

  Widget _list() {
    final items = _visible;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open,
                size: 56, color: AppColors.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('This folder is empty',
                style: TextStyle(color: AppColors.onSurfaceVariant)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (c, i) {
          final e = items[i];
          final selected = _selected.contains(e.path);
          return ListTile(
            leading: selected
                ? const Icon(Icons.check_circle, color: Colors.blue)
                : Icon(_iconFor(e), color: AppColors.onSurfaceVariant),
            title: Text(e.name,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(_subtitle(e)),
            selected: selected,
            onTap: () => _open(e),
            onLongPress: () => _toggleSelect(e),
            trailing: _selecting
                ? null
                : IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showFileActions(e),
                  ),
          );
        },
      ),
    );
  }
}
