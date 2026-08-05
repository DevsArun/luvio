import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Luvio Player type scale — Inter, sized exactly per the design system.
///
/// Styles are getters so their default color always resolves against the
/// active palette (dark or light) at build time.
abstract final class AppTypography {
  static const String fontFamily = 'Inter';

  /// display-lg — 48/56, w700, -0.02em
  static TextStyle get displayLg => TextStyle(
        fontFamily: fontFamily,
        fontSize: 48,
        height: 56 / 48,
        fontWeight: FontWeight.w700,
        letterSpacing: 48 * -0.02,
        color: AppColors.onSurface,
      );

  /// headline-lg — 32/40, w600
  static TextStyle get headlineLg => TextStyle(
        fontFamily: fontFamily,
        fontSize: 32,
        height: 40 / 32,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      );

  /// headline-md — 24/32, w600
  static TextStyle get headlineMd => TextStyle(
        fontFamily: fontFamily,
        fontSize: 24,
        height: 32 / 24,
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      );

  /// body-lg — 18/28, w400
  static TextStyle get bodyLg => TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        height: 28 / 18,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurface,
      );

  /// body-md — 16/24, w400
  static TextStyle get bodyMd => TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
        color: AppColors.onSurface,
      );

  /// label-lg — 14/20, w500, +0.1
  static TextStyle get labelLg => TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: AppColors.onSurface,
      );

  /// label-md — 12/16, w500, +0.5
  static TextStyle get labelMd => TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: AppColors.onSurface,
      );

  static TextTheme get textTheme => TextTheme(
        displayLarge: displayLg,
        headlineLarge: headlineLg,
        headlineMedium: headlineMd,
        bodyLarge: bodyLg,
        bodyMedium: bodyMd,
        labelLarge: labelLg,
        labelMedium: labelMd,
      );
}
