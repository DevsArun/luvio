import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// `headline-md` section title row with optional trailing action
/// (e.g. "Storage & Folders"  …  "Manage All").
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: 24),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(title, style: AppTypography.headlineMd),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Uppercase `label-md` micro-header (e.g. `RECENT SEARCHES`, `GENERAL`).
class MicroHeader extends StatelessWidget {
  const MicroHeader(
    this.label, {
    super.key,
    this.color,
    this.padding = const EdgeInsets.only(bottom: 16),
  });

  final String label;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        label.toUpperCase(),
        style: AppTypography.labelMd.copyWith(
          color: color ?? AppColors.onSurfaceVariant.withOpacity(0.7),
          letterSpacing: 1.6,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
