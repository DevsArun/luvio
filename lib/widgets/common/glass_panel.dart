import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';

/// Signature glassmorphism container: 20px backdrop blur over an 80%-opacity
/// surface, hairline white border and the diffused ambient shadow.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = AppRadius.container,
    this.color,
    this.padding,
    this.borderColor,
    this.blur = 20,
    this.shadow = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final double blur;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadow ? AppColors.ambientShadow : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color ?? AppColors.surfaceContainerLow.withOpacity(0.8),
              borderRadius: borderRadius,
              border: Border.all(
                color: borderColor ?? Colors.white.withOpacity(0.05),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
