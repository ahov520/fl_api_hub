import 'package:flutter/material.dart';

import '../../../app/theme/design_tokens.dart';

/// Shared stat tile for dashboard grids.
///
/// Displays a value with a label and an optional icon, extracted from the
/// private `_StatCell` in `CheckInStatsGrid` so it can be reused on the
/// balance overview card and elsewhere.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
  });

  /// Short caption above the value.
  final String label;

  /// Main metric text.
  final String value;

  /// Optional leading icon.
  final IconData? icon;

  /// Optional override colour for icon and value.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: effectiveColor),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: effectiveColor,
          ),
        ),
      ],
    );
  }
}
