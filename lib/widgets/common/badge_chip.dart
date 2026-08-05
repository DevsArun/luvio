import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Small metadata chip: duration badges, `4K HDR`, `NEW`, codec tags…
class BadgeChip extends StatelessWidget {
  const BadgeChip({
    super.key,
    required this.label,
    this.color,
    this.textColor,
    this.icon,
    this.glass = false,
  });

  /// Solid dark duration badge used on thumbnails.
  BadgeChip.duration(String duration, {Key? key})
      : this(
          key: key,
          label: duration,
          color: Color(0xCC000000),
          textColor: Colors.white,
        );

  final String label;
  final Color? color;
  final Color? textColor;
  final IconData? icon;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color ?? AppColors.primaryContainer.withOpacity(0.9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor ?? Colors.white),
            SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.labelMd.copyWith(
              color: textColor ?? AppColors.onPrimaryContainer,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
    if (!glass) return chip;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: chip,
      ),
    );
  }
}
