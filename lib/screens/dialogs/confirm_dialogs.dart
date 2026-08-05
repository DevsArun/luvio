import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Destructive delete confirmation. Returns true when confirmed.
Future<bool> showDeleteConfirmDialog(
  BuildContext context, {
  required String title,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.errorContainer.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child:
            Icon(Icons.delete_outline, color: AppColors.error),
      ),
      title: Text('Delete video?'),
      content: Text(
        'This will permanently delete “$title” from your device. '
        'This action cannot be undone.',
        style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant.withOpacity(0.8)),
      ),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.errorContainer,
            foregroundColor: AppColors.onErrorContainer,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Delete'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Rename dialog — returns the new file name (with the original
/// extension re-applied), or null when cancelled.
Future<String?> showRenameDialog(
  BuildContext context, {
  required String currentFileName,
}) {
  final dot = currentFileName.lastIndexOf('.');
  final base = dot > 0 ? currentFileName.substring(0, dot) : currentFileName;
  final extension = dot > 0 ? currentFileName.substring(dot) : '';
  final controller = TextEditingController(text: base);

  return showDialog<String>(
    context: context,
    builder: (context) {
      void submit() {
        final name = controller.text.trim();
        if (name.isEmpty) return;
        Navigator.of(context).pop('$name$extension');
      }

      return AlertDialog(
        title: Text('Rename video'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                style: AppTypography.bodyMd,
                decoration: InputDecoration(
                  hintText: 'File name',
                  suffixText: extension,
                  suffixStyle: AppTypography.labelLg.copyWith(
                      color: AppColors.onSurfaceVariant
                          .withOpacity(0.6)),
                ),
                onSubmitted: (_) => submit(),
              ),
              SizedBox(height: 10),
              Text(
                'The file extension is kept automatically.',
                style: AppTypography.labelMd.copyWith(
                    color: AppColors.onSurfaceVariant
                        .withOpacity(0.6)),
              ),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(
            borderRadius: AppRadius.container),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          FilledButton(
            onPressed: submit,
            child: Text('Save'),
          ),
        ],
      );
    },
  );
}
