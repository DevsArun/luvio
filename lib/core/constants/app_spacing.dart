import 'package:flutter/material.dart';

/// Spacing, radii and hit-target constants from the design system.
abstract final class AppSpacing {
  /// 8px linear rhythm unit.
  static const double unit = 8;

  /// Generous 32px outer margin (thumb-safe edges while holding the tablet).
  static const double containerPadding = 32;

  /// 24px gutter between thumbnails / columns.
  static const double gutter = 24;

  /// Minimum interactive hit area (48x48dp).
  static const double touchTargetMin = 48;

  /// Primary playback controls exceed 64dp.
  static const double playbackControl = 64;

  /// Centered play/pause control (80dp).
  static const double playbackControlLarge = 80;

  /// 24px gap between cards.
  static const double cardGap = 24;
}

/// Corner radii from the design system (`rounded` scale + 24px containers).
abstract final class AppRadius {
  static const double sm = 4;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;
  static const double xxl = 24;

  /// Signature 24px container radius (cards, thumbnails, modal sheets).
  static const BorderRadius container = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius card = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius panel = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius chip = BorderRadius.all(Radius.circular(md));
  static const BorderRadius chipRadius = chip;

  /// Pill shape for actionable elements.
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));
}

/// Motion tokens — premium, fluid, natural.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration hero = Duration(milliseconds: 700);
  static const Curve ease = Cubic(0.4, 0, 0.2, 1);
  static const Curve emphasized = Cubic(0.2, 0, 0, 1);
}
