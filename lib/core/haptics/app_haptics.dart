import 'package:flutter/services.dart';

/// Centralised haptic feedback entry points.
///
/// Keeps vibration patterns consistent and makes it easy to disable or
/// restyle feedback globally in the future.
abstract final class AppHaptics {
  /// Light impact — swipe actions, small toggles, reorder.
  static Future<void> light() => HapticFeedback.lightImpact();

  /// Medium impact — long-press menus, important confirmations.
  static Future<void> medium() => HapticFeedback.mediumImpact();

  /// Selection click — tab switches, FAB taps, chip selections.
  static Future<void> selection() => HapticFeedback.selectionClick();
}
