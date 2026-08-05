import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/file_manager_service.dart';

/// Shows soft-deleted items with restore / delete-forever / empty-bin actions.
class RecycleBinScreen extends StatefulWidget {
  const RecycleBinScreen({super.key});

  @override
  State<RecycleBinScreen> createState() => _RecycleBinScreenState();
}

class _RecycleBinScreenState extends State<RecycleBinScreen> {
  final FileManagerService _svc = FileManagerService();
  List<TrashedEntry> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _svc.listTrash();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _restore(TrashedEntry e) async {
    final ok = await _svc.restore(e);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Restored ${e.name}' : 'Restore failed')),
    );
    await _load();
  }

  Future<void> _deleteForever(TrashedEntry e) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: Text('${e.name} will be gone forever.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    await _svc.deleteForever(e);
    await _load();
  }

  Future<void> _emptyBin() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Empty recycle bin?'),
        content: const Text('All items will be permanently deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Empty')),
        ],
      ),
    );
    if (confirm != true) return;
    await _svc.emptyTrash();
    await _load();
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: const Text('Recycle Bin'),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: 'Empty bin',
                onPressed: _emptyBin),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline,
                          size: 56, color: AppColors.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text('Recycle bin is empty',
                          style:
                              TextStyle(color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (c, i) {
                    final e = _items[i];
                    return ListTile(
                      leading: Icon(
                          e.isDirectory
                              ? Icons.folder_outlined
                              : Icons.insert_drive_file_outlined,
                          color: AppColors.onSurfaceVariant),
                      title: Text(e.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          '${_bytes(e.sizeBytes)} · deleted '
                          '${e.deletedAt.toString().split('.').first}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                              icon: const Icon(Icons.restore),
                              tooltip: 'Restore',
                              onPressed: () => _restore(e)),
                          IconButton(
                              icon: const Icon(Icons.delete_forever),
                              tooltip: 'Delete forever',
                              onPressed: () => _deleteForever(e)),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
