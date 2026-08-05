import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_spacing.dart';
import 'app_colors.dart';
import 'app_typography.dart';

/// Builds the Material 3 theme for Luvio Player from the design tokens.
abstract final class AppTheme {

  /// Light companion theme for the Settings "Dark Theme" toggle. Core
  /// screens keep their cinematic dark surfaces (the design system is
  /// dark-first); Material dialogs, menus and pickers switch to light.
  /// Both entry points build from the ACTIVE palette (AppColors.isLight
  /// is set centrally in app.dart), so the entire UI recolors.
  static ThemeData light() => dark();

  static ThemeData dark() {
    final scheme = AppColors.scheme;
    final textTheme = AppTypography.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      fontFamily: AppTypography.fontFamily,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: AppColors.isLight
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      iconTheme: IconThemeData(color: AppColors.onSurfaceVariant, size: 24),
      dividerTheme: DividerThemeData(
        color: AppColors.white05,
        thickness: 1,
        space: 1,
      ),
      // Pill-shaped primary buttons with the #5B5BFF fill.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryContainer,
          foregroundColor: AppColors.onPrimaryContainer,
          minimumSize: Size(64, AppSpacing.touchTargetMin),
          padding: EdgeInsets.symmetric(horizontal: 32),
          shape: StadiumBorder(),
          textStyle: AppTypography.labelLg,
        ),
      ),
      // Ghost secondary buttons with a 2px stroke.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onSurface,
          minimumSize: Size(64, AppSpacing.touchTargetMin),
          padding: EdgeInsets.symmetric(horizontal: 32),
          side: BorderSide(color: AppColors.outlineVariant, width: 2),
          shape: StadiumBorder(),
          textStyle: AppTypography.labelLg,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTypography.labelLg,
          shape: StadiumBorder(),
        ),
      ),
      // Customized M3 switch (primary color, tablet-visible strokes).
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.onPrimaryContainer;
          }
          return AppColors.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryContainer;
          }
          return AppColors.surfaceContainerHighest;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return AppColors.outline;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        side: BorderSide(color: AppColors.outline, width: 2.5),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryContainer;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(AppColors.onPrimaryContainer),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primaryContainer;
          }
          return AppColors.outline;
        }),
      ),
      // High-precision seeker: 4px track, large 24px thumb.
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: AppColors.primaryContainer,
        inactiveTrackColor: AppColors.white20,
        thumbColor: AppColors.primaryContainer,
        overlayColor: AppColors.primaryContainer.withOpacity(0.15),
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 24),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primaryContainer,
        linearTrackColor: AppColors.surfaceContainerHighest,
        circularTrackColor: AppColors.surfaceContainerHighest,
      ),
      // NOTE: DialogTheme (not DialogThemeData) — DialogThemeData only exists
      // in Flutter 3.27+. Keep this compatible with the 3.24.x CI toolchain.
      dialogTheme: DialogTheme(
        backgroundColor: AppColors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.container,
          side: BorderSide(color: AppColors.white05),
        ),
        titleTextStyle: AppTypography.headlineMd,
        contentTextStyle: AppTypography.bodyMd
            .copyWith(color: AppColors.onSurfaceVariant),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
          side: BorderSide(color: AppColors.white05),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.panel,
          side: BorderSide(color: AppColors.white10),
        ),
        textStyle: AppTypography.bodyMd,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceContainerHigh,
        contentTextStyle: AppTypography.bodyMd,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHighest,
          borderRadius: AppRadius.chip,
        ),
        textStyle: AppTypography.labelMd,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainer.withOpacity(0.8),
        hintStyle: AppTypography.bodyMd.copyWith(
          color: AppColors.onSurfaceVariant.withOpacity(0.5),
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.pill,
          borderSide: BorderSide(color: AppColors.outlineVariant.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.pill,
          borderSide: BorderSide(color: AppColors.outlineVariant.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.pill,
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(AppColors.white20),
        radius: Radius.circular(8),
        thickness: WidgetStatePropertyAll(6),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
