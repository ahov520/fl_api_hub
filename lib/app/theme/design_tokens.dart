import 'package:flutter/material.dart';

/// Design tokens from DESIGN.md / Stitch design system.
///
/// All color, spacing, and radius constants live here so that every widget
/// references a single source of truth.
///
/// Primary:   #6750a4 (brand / CTAs)
/// Secondary: #625b71 (secondary elements)
/// Tertiary:  #7d5260 (accents / highlights)
/// Neutral:   #79747e (backgrounds / surfaces)
abstract final class AppColors {
  static const primary = Color(0xFF6750A4);
  static const secondary = Color(0xFF625B71);
  static const tertiary = Color(0xFF7D5260);
  static const neutral = Color(0xFF79747E);
}

/// Spacing scale (4 px base unit).
abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

/// Border radius scale.
abstract final class AppRadius {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 28.0;
}

/// Motion duration tokens.
///
/// Use these instead of hard-coded [Duration] literals so that motion feels
/// consistent across the app and can be tuned in one place.
abstract final class AppDuration {
  /// Micro-interactions: icon fades, switch flips, dot pulses.
  static const fast = Duration(milliseconds: 150);

  /// Standard transitions: tab switches, card expands, page pushes.
  static const normal = Duration(milliseconds: 300);

  /// Emphasized entrances: dialogs, bottom sheets, hero expansions.
  static const slow = Duration(milliseconds: 500);
}

/// Elevation tokens (Material 3 surface elevation levels).
abstract final class AppElevation {
  static const level0 = 0.0;
  static const level1 = 1.0;
  static const level2 = 3.0;
  static const level3 = 6.0;
}

/// Curve tokens for common motion patterns.
abstract final class AppMotion {
  /// Emphasized decelerate — incoming elements (cards, dialogs).
  static const emphasizedDecelerate = Curves.easeOutCubic;

  /// Emphasized accelerate — outgoing elements (dismiss, exit).
  static const emphasizedAccelerate = Curves.easeInCubic;

  /// Standard easing for most transitions.
  static const standard = Curves.easeInOut;
}

/// Semantic status colors.
///
/// These are used for account health, check-in results, and balance alerts.
/// They are *not* part of the brand palette and therefore stay constant in
/// both light and dark mode (only their container/foreground pair changes).
abstract final class StatusColors {
  /// Emerald — success, healthy balance, check-in succeeded.
  static const success = Color(0xFF059669);

  /// Amber — warning, low balance, check-in pending.
  static const warning = Color(0xFFD97706);

  /// Red — error, failed check-in, unreachable account.
  static const error = Color(0xFFDC2626);

  /// Slate — neutral / unknown / disabled status.
  static const neutral = Color(0xFF64748B);
}

/// Responsive layout breakpoint.
///
/// Pages switch from a single-column (narrow) layout to a master-detail
/// (wide) layout at this width. Keep in sync with the [SplitPane] usage.
const double kWideBreakpoint = 900.0;
