import 'package:flutter/material.dart';

/// Dark palette — MX Player style: near-black neutral greys with a single
/// bright blue accent (no purple tint anywhere).
abstract final class _D {
  static const Color surface = Color(0xFF121212);
  static const Color surfaceDim = Color(0xFF0E0E0E);
  static const Color surfaceBright = Color(0xFF2C2C2C);
  static const Color surfaceContainerLowest = Color(0xFF0A0A0A);
  static const Color surfaceContainerLow = Color(0xFF161616);
  static const Color surfaceContainer = Color(0xFF1C1C1C);
  static const Color surfaceContainerHigh = Color(0xFF242424);
  static const Color surfaceContainerHighest = Color(0xFF2E2E2E);
  static const Color onSurface = Color(0xFFECECEC);
  static const Color onSurfaceVariant = Color(0xFFB0B0B0);
  static const Color inverseSurface = Color(0xFFECECEC);
  static const Color inverseOnSurface = Color(0xFF2A2A2A);
  static const Color outline = Color(0xFF8A8A8A);
  static const Color outlineVariant = Color(0xFF3A3A3A);
  static const Color surfaceTint = Color(0xFF3D8BFD);
  static const Color surfaceVariant = Color(0xFF2E2E2E);

  // MX Player signature blue.
  static const Color primary = Color(0xFF3D8BFD);
  static const Color onPrimary = Color(0xFF00224C);
  static const Color primaryContainer = Color(0xFF1877F2);
  static const Color onPrimaryContainer = Color(0xFFFFFFFF);
  static const Color inversePrimary = Color(0xFF0B5ED7);
  static const Color primaryFixed = Color(0xFFD3E4FF);
  static const Color primaryFixedDim = Color(0xFF3D8BFD);
  static const Color onPrimaryFixed = Color(0xFF001A41);
  static const Color onPrimaryFixedVariant = Color(0xFF0B5ED7);

  static const Color secondary = Color(0xFF9FC4F5);
  static const Color onSecondary = Color(0xFF10314F);
  static const Color secondaryContainer = Color(0xFF19477A);
  static const Color onSecondaryContainer = Color(0xFFD3E4FF);
  static const Color secondaryFixed = Color(0xFFD3E4FF);
  static const Color secondaryFixedDim = Color(0xFF9FC4F5);

  // MX's orange highlight (progress / "resume" markers).
  static const Color tertiary = Color(0xFFFFA726);
  static const Color onTertiary = Color(0xFF442B00);
  static const Color tertiaryContainer = Color(0xFFF57C00);
  static const Color onTertiaryContainer = Color(0xFFFFFFFF);
  static const Color tertiaryFixed = Color(0xFFFFE0B2);
  static const Color tertiaryFixedDim = Color(0xFFFFA726);

  static const Color error = Color(0xFFFF6B6B);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onErrorContainer = Color(0xFFFFDAD6);

  static const Color background = Color(0xFF121212);
  static const Color onBackground = Color(0xFFECECEC);

  static const Color card = Color(0xFF1C1C1C);
  static const Color accentPurple = Color(0xFF1877F2);
  static const Color accentCyan = Color(0xFF4FC3F7);
}

/// Light companion palette — same hues, tuned for readability on white.
abstract final class _L {
  static const Color surface = Color(0xFFFBF8FF);
  static const Color surfaceDim = Color(0xFFDBD9E4);
  static const Color surfaceBright = Color(0xFFFBF8FF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF5F2FC);
  static const Color surfaceContainer = Color(0xFFEFECF6);
  static const Color surfaceContainerHigh = Color(0xFFE9E6F1);
  static const Color surfaceContainerHighest = Color(0xFFE3E1EB);
  static const Color onSurface = Color(0xFF1B1B22);
  static const Color onSurfaceVariant = Color(0xFF46464F);
  static const Color inverseSurface = Color(0xFF303036);
  static const Color inverseOnSurface = Color(0xFFF2F0F7);
  static const Color outline = Color(0xFF777680);
  static const Color outlineVariant = Color(0xFFC7C5D0);
  static const Color surfaceTint = Color(0xFF1877F2);
  static const Color surfaceVariant = Color(0xFFE3E1EB);

  static const Color primary = Color(0xFF1877F2);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF0B5ED7);
  static const Color onPrimaryContainer = Color(0xFFFFFFFF);
  static const Color inversePrimary = Color(0xFF9FC4F5);
  static const Color primaryFixed = Color(0xFFD3E4FF);
  static const Color primaryFixedDim = Color(0xFF9FC4F5);
  static const Color onPrimaryFixed = Color(0xFF001A41);
  static const Color onPrimaryFixedVariant = Color(0xFF0B5ED7);

  static const Color secondary = Color(0xFF19477A);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFD3E4FF);
  static const Color onSecondaryContainer = Color(0xFF001A41);
  static const Color secondaryFixed = Color(0xFFD3E4FF);
  static const Color secondaryFixedDim = Color(0xFF9FC4F5);

  static const Color tertiary = Color(0xFFEF6C00);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFFFE0B2);
  static const Color onTertiaryContainer = Color(0xFF3E2500);
  static const Color tertiaryFixed = Color(0xFFFFE0B2);
  static const Color tertiaryFixedDim = Color(0xFFFFA726);

  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF410002);

  static const Color background = Color(0xFFF4F2FB);
  static const Color onBackground = Color(0xFF1B1B22);

  static const Color card = Color(0xFFFFFFFF);
  static const Color accentPurple = Color(0xFF1877F2);
  static const Color accentCyan = Color(0xFF0288D1);
}

/// Luvio Player design-system palette.
///
/// Runtime-switchable: set [isLight] (done centrally in `app.dart` from the
/// Settings "Dark Theme" toggle) and every getter below resolves to the
/// matching palette, so the whole UI recolors — MX-Player-style.
abstract final class AppColors {
  /// Flipped by the app root whenever the theme setting changes.
  static bool isLight = false;

  // --- Surfaces -------------------------------------------------------------
  static Color get surface => isLight ? _L.surface : _D.surface;
  static Color get surfaceDim => isLight ? _L.surfaceDim : _D.surfaceDim;
  static Color get surfaceBright =>
      isLight ? _L.surfaceBright : _D.surfaceBright;
  static Color get surfaceContainerLowest =>
      isLight ? _L.surfaceContainerLowest : _D.surfaceContainerLowest;
  static Color get surfaceContainerLow =>
      isLight ? _L.surfaceContainerLow : _D.surfaceContainerLow;
  static Color get surfaceContainer =>
      isLight ? _L.surfaceContainer : _D.surfaceContainer;
  static Color get surfaceContainerHigh =>
      isLight ? _L.surfaceContainerHigh : _D.surfaceContainerHigh;
  static Color get surfaceContainerHighest =>
      isLight ? _L.surfaceContainerHighest : _D.surfaceContainerHighest;
  static Color get onSurface => isLight ? _L.onSurface : _D.onSurface;
  static Color get onSurfaceVariant =>
      isLight ? _L.onSurfaceVariant : _D.onSurfaceVariant;
  static Color get inverseSurface =>
      isLight ? _L.inverseSurface : _D.inverseSurface;
  static Color get inverseOnSurface =>
      isLight ? _L.inverseOnSurface : _D.inverseOnSurface;
  static Color get outline => isLight ? _L.outline : _D.outline;
  static Color get outlineVariant =>
      isLight ? _L.outlineVariant : _D.outlineVariant;
  static Color get surfaceTint => isLight ? _L.surfaceTint : _D.surfaceTint;
  static Color get surfaceVariant =>
      isLight ? _L.surfaceVariant : _D.surfaceVariant;

  // --- Primary ---------------------------------------------------------------
  static Color get primary => isLight ? _L.primary : _D.primary;
  static Color get onPrimary => isLight ? _L.onPrimary : _D.onPrimary;
  static Color get primaryContainer =>
      isLight ? _L.primaryContainer : _D.primaryContainer;
  static Color get onPrimaryContainer =>
      isLight ? _L.onPrimaryContainer : _D.onPrimaryContainer;
  static Color get inversePrimary =>
      isLight ? _L.inversePrimary : _D.inversePrimary;
  static Color get primaryFixed => isLight ? _L.primaryFixed : _D.primaryFixed;
  static Color get primaryFixedDim =>
      isLight ? _L.primaryFixedDim : _D.primaryFixedDim;
  static Color get onPrimaryFixed =>
      isLight ? _L.onPrimaryFixed : _D.onPrimaryFixed;
  static Color get onPrimaryFixedVariant =>
      isLight ? _L.onPrimaryFixedVariant : _D.onPrimaryFixedVariant;

  // --- Secondary --------------------------------------------------------------
  static Color get secondary => isLight ? _L.secondary : _D.secondary;
  static Color get onSecondary => isLight ? _L.onSecondary : _D.onSecondary;
  static Color get secondaryContainer =>
      isLight ? _L.secondaryContainer : _D.secondaryContainer;
  static Color get onSecondaryContainer =>
      isLight ? _L.onSecondaryContainer : _D.onSecondaryContainer;
  static Color get secondaryFixed =>
      isLight ? _L.secondaryFixed : _D.secondaryFixed;
  static Color get secondaryFixedDim =>
      isLight ? _L.secondaryFixedDim : _D.secondaryFixedDim;

  // --- Tertiary ----------------------------------------------------------------
  static Color get tertiary => isLight ? _L.tertiary : _D.tertiary;
  static Color get onTertiary => isLight ? _L.onTertiary : _D.onTertiary;
  static Color get tertiaryContainer =>
      isLight ? _L.tertiaryContainer : _D.tertiaryContainer;
  static Color get onTertiaryContainer =>
      isLight ? _L.onTertiaryContainer : _D.onTertiaryContainer;
  static Color get tertiaryFixed =>
      isLight ? _L.tertiaryFixed : _D.tertiaryFixed;
  static Color get tertiaryFixedDim =>
      isLight ? _L.tertiaryFixedDim : _D.tertiaryFixedDim;

  // --- Error ---------------------------------------------------------------
  static Color get error => isLight ? _L.error : _D.error;
  static Color get onError => isLight ? _L.onError : _D.onError;
  static Color get errorContainer =>
      isLight ? _L.errorContainer : _D.errorContainer;
  static Color get onErrorContainer =>
      isLight ? _L.onErrorContainer : _D.onErrorContainer;

  // --- Background ------------------------------------------------------------
  static Color get background => isLight ? _L.background : _D.background;
  static Color get onBackground => isLight ? _L.onBackground : _D.onBackground;

  // --- Brand accents used in the reference layouts ----------------------------
  /// Near-black base used by the splash and player chrome. Kept dark in both
  /// themes — video surfaces should always be cinematic.
  static const Color deepNight = Color(0xFF000000);

  /// Elevated content-card surface.
  static Color get card => isLight ? _L.card : _D.card;

  /// Purple accent for category distinctions (e.g. Folders).
  static Color get accentPurple => isLight ? _L.accentPurple : _D.accentPurple;

  /// Cyan accent reserved for secondary information / "NEW" badges.
  static Color get accentCyan => isLight ? _L.accentCyan : _D.accentCyan;

  // --- Common alpha helpers used across the reference markup -----------------
  /// Hairline overlay tints: white on dark surfaces, black on light ones.
  static Color get white05 =>
      (isLight ? Colors.black : Colors.white).withOpacity(0.05);
  static Color get white10 =>
      (isLight ? Colors.black : Colors.white).withOpacity(0.10);
  static Color get white20 =>
      (isLight ? Colors.black : Colors.white).withOpacity(0.20);

  /// Diffused ambient shadow (Blur 32) from the design system.
  static List<BoxShadow> get ambientShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(isLight ? 0.18 : 0.40),
          blurRadius: 32,
          offset: const Offset(0, 16),
        ),
      ];

  /// Primary glow used on prominent pill buttons / play controls.
  static List<BoxShadow> get primaryGlow => [
        BoxShadow(
          color: primaryContainer.withOpacity(isLight ? 0.30 : 0.40),
          blurRadius: 24,
          offset: const Offset(0, 4),
        ),
      ];

  /// Scheme matching the active palette.
  static ColorScheme get scheme => isLight ? lightScheme : darkScheme;

  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: _D.primary,
    onPrimary: _D.onPrimary,
    primaryContainer: _D.primaryContainer,
    onPrimaryContainer: _D.onPrimaryContainer,
    inversePrimary: _D.inversePrimary,
    secondary: _D.secondary,
    onSecondary: _D.onSecondary,
    secondaryContainer: _D.secondaryContainer,
    onSecondaryContainer: _D.onSecondaryContainer,
    tertiary: _D.tertiary,
    onTertiary: _D.onTertiary,
    tertiaryContainer: _D.tertiaryContainer,
    onTertiaryContainer: _D.onTertiaryContainer,
    error: _D.error,
    onError: _D.onError,
    errorContainer: _D.errorContainer,
    onErrorContainer: _D.onErrorContainer,
    surface: _D.surface,
    onSurface: _D.onSurface,
    surfaceDim: _D.surfaceDim,
    surfaceBright: _D.surfaceBright,
    surfaceContainerLowest: _D.surfaceContainerLowest,
    surfaceContainerLow: _D.surfaceContainerLow,
    surfaceContainer: _D.surfaceContainer,
    surfaceContainerHigh: _D.surfaceContainerHigh,
    surfaceContainerHighest: _D.surfaceContainerHighest,
    onSurfaceVariant: _D.onSurfaceVariant,
    outline: _D.outline,
    outlineVariant: _D.outlineVariant,
    inverseSurface: _D.inverseSurface,
    onInverseSurface: _D.inverseOnSurface,
    surfaceTint: _D.surfaceTint,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: _L.primary,
    onPrimary: _L.onPrimary,
    primaryContainer: _L.primaryContainer,
    onPrimaryContainer: _L.onPrimaryContainer,
    inversePrimary: _L.inversePrimary,
    secondary: _L.secondary,
    onSecondary: _L.onSecondary,
    secondaryContainer: _L.secondaryContainer,
    onSecondaryContainer: _L.onSecondaryContainer,
    tertiary: _L.tertiary,
    onTertiary: _L.onTertiary,
    tertiaryContainer: _L.tertiaryContainer,
    onTertiaryContainer: _L.onTertiaryContainer,
    error: _L.error,
    onError: _L.onError,
    errorContainer: _L.errorContainer,
    onErrorContainer: _L.onErrorContainer,
    surface: _L.surface,
    onSurface: _L.onSurface,
    surfaceDim: _L.surfaceDim,
    surfaceBright: _L.surfaceBright,
    surfaceContainerLowest: _L.surfaceContainerLowest,
    surfaceContainerLow: _L.surfaceContainerLow,
    surfaceContainer: _L.surfaceContainer,
    surfaceContainerHigh: _L.surfaceContainerHigh,
    surfaceContainerHighest: _L.surfaceContainerHighest,
    onSurfaceVariant: _L.onSurfaceVariant,
    outline: _L.outline,
    outlineVariant: _L.outlineVariant,
    inverseSurface: _L.inverseSurface,
    onInverseSurface: _L.inverseOnSurface,
    surfaceTint: _L.surfaceTint,
    shadow: Colors.black,
    scrim: Colors.black,
  );
}
