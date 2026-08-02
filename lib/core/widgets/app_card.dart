import 'package:flutter/material.dart';

import '../../../app/theme/design_tokens.dart';

/// Shared content card recipe.
///
/// Standardises the radius, padding, border and colour that were previously
/// split across `Card`, `Material` and `Container` implementations.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.selected = false,
  });

  /// Card content.
  final Widget child;

  /// Inner padding (defaults to 20 on all sides).
  final EdgeInsetsGeometry padding;

  /// Optional tap handler (adds ripple).
  final VoidCallback? onTap;

  /// Whether the card is in a selected state (shows primary border).
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = selected
        ? colorScheme.primary.withValues(alpha: 0.5)
        : colorScheme.outlineVariant.withValues(alpha: 0.15);

    final card = Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor, width: selected ? 1.5 : 1),
      ),
      padding: padding,
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: card,
      ),
    );
  }
}
