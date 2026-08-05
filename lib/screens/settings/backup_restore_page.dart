import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../services/backup_service.dart';

/// Part 7 — Backup & Restore settings sub-page. Rendered inside the settings
/// AnimatedSwitcher (same onBack pattern as the other sub-pages).
class BackupRestorePage extends StatefulWidget {
  const BackupRestorePage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends State<BackupRestorePage> {
  final BackupService _svc = BackupService();
  bool _busy = false;

  Future<void> _run(Future<BackupResult> Function() op) async {
    setState(() => _busy = true);
    final r = await op();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(r.message)));
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 96),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 896),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: widget.onBack,
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 8),
                      Text('Backup & Restore',
                          style: Theme.of(context).textTheme.headlineSmall),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Export all app settings, playlists, favorites and library '
                    'index to a JSON file, then restore them on any device.',
                    style: TextStyle(
                        color: AppColors.onSurfaceVariant.withOpacity(0.8)),
                  ),
                  const SizedBox(height: 24),
                  if (_busy) const LinearProgressIndicator(),
                  Card(
                    color: AppColors.surfaceContainerHigh,
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.upload_file_outlined),
                          title: const Text('Export backup'),
                          subtitle:
                              const Text('Save a .json backup you can keep'),
                          onTap: _busy ? null : () => _run(_svc.export),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.download_outlined),
                          title: const Text('Restore backup'),
                          subtitle: const Text('Import a .json backup file'),
                          onTap: _busy ? null : () => _run(_svc.import),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
