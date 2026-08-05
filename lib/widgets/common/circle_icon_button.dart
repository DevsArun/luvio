import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';

/// 48px circular action button (glass or tinted) used across top bars,
/// players and toolbars. Always meets the minimum touch target.
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.size = AppSpacing.touchTargetMin,
    this.iconSize = 24,
    this.color,
    this.iconColor,
    this.glass = false,
    this.border = false,
    this.filled = false,
    this.glow = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double iconSize;
  final Color? color;
  final Color? iconColor;

  /// Frosted-glass background (used over video / imagery).
  final bool glass;
  final bool border;

  /// Solid primary-container fill (prominent playback actions).
  final bool filled;

  /// Adds the signature #5B5BFF glow shadow.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final background = filled
        ? AppColors.primaryContainer
        : color ?? (glass ? Colors.white.withOpacity(0.10) : Colors.transparent);
    final foreground = iconColor ??
        (filled ? AppColors.onPrimaryContainer : AppColors.onSurface);

    Widget button = Material(
      color: background,
      shape: CircleBorder(
        side: border
            ? BorderSide(color: Colors.white.withOpacity(0.10))
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: CircleBorder(),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: foreground),
        ),
      ),
    );

    if (glass) {
      button = ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: button,
        ),
      );
    }

    if (glow) {
      button = DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: AppColors.primaryGlow,
        ),
        child: button,
      );
    }

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return Semantics(button: true, label: tooltip, child: button);
  }
}
