import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Send Feedback dialog: category chips + message field; submits through the
/// system share sheet (fully offline-friendly, no hidden network calls).
Future<void> showFeedbackDialog(BuildContext context) {
  final controller = TextEditingController();
  String category = 'Bug Report';
  final categories = ['Bug Report', 'Feature Request', 'Playback Issue', 'Other'];

  return showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Send Feedback'),
        content: ConstrainedBox(
          constraints: BoxConstraints(minWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in categories)
                    ChoiceChip(
                      label: Text(c),
                      selected: category == c,
                      selectedColor: AppColors.primaryContainer,
                      labelStyle: AppTypography.labelLg.copyWith(
                        color: category == c
                            ? AppColors.onPrimaryContainer
                            : AppColors.onSurfaceVariant,
                      ),
                      onSelected: (_) => setState(() => category = c),
                    ),
                ],
              ),
              SizedBox(height: 20),
              TextField(
                controller: controller,
                maxLines: 5,
                style: AppTypography.bodyMd,
                decoration: InputDecoration(
                  hintText: 'Describe your experience or the issue…',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                        color: AppColors.outlineVariant.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                        color: AppColors.primary, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          FilledButton.icon(
            icon: Icon(Icons.send, size: 18),
            onPressed: () {
              final message = controller.text.trim();
              Navigator.of(context).pop();
              if (message.isEmpty) return;
              Share.share(
                'Luvio Player Feedback — $category\n\n$message\n\n'
                'App version: 2.6.0 (Build 5100)',
                subject: 'Luvio Player Feedback — $category',
              );
            },
            label: Text('Send Feedback'),
          ),
        ],
      ),
    ),
  );
}
