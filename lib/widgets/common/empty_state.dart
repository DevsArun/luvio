import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Centered empty/error state: oversized dim icon, `headline-md` title and a
/// muted explanation, with an optional action button — exactly the pattern
/// used by the reference search screen (`search_off` / "No results found").
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 96,
              color: AppColors.onSurfaceVariant.withOpacity(0.20),
            ),
            SizedBox(height: 24),
            Text(title,
                style: AppTypography.headlineMd, textAlign: TextAlign.center),
            SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant.withOpacity(0.6),
              ),
            ),
            if (action != null) ...[
              SizedBox(height: 32),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
