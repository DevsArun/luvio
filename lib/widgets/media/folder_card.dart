import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Folder / storage-location card with icon tile, name and metadata.
class FolderCard extends StatelessWidget {
  const FolderCard({
    super.key,
    required this.name,
    required this.subtitle,
    this.icon = Icons.folder,
    this.accentColor,
    this.progress,
    this.onTap,
  });

  final String name;
  final String subtitle;
  final IconData icon;
  final Color? accentColor;

  /// Optional storage-used fraction 0..1.
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.primaryContainer;
    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: AppRadius.card,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: AppRadius.card,
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.18),
                  borderRadius: AppRadius.panel,
                ),
                child: Icon(icon, color: accent, size: 26),
              ),
              SizedBox(height: 16),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyLg
                    .copyWith(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelMd.copyWith(
                    color:
                        AppColors.onSurfaceVariant.withOpacity(0.7)),
              ),
              if (progress != null) ...[
                SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress!.clamp(0.0, 1.0),
                    minHeight: 4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
