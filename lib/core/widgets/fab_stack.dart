import 'package:flutter/material.dart';

import '../../../app/theme/design_tokens.dart';

/// Shared floating-action-button stack used by the main tabs.
///
/// Shows a compact 48×48 secondary refresh button above the primary action
/// button. The refresh button rotates while [isRefreshing] is true.
class FabStack extends StatelessWidget {
  const FabStack({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.onRefresh,
    this.isRefreshing = false,
    this.heroTag,
  });

  /// Primary action callback.
  final VoidCallback onPressed;

  /// Icon for the primary action.
  final IconData icon;

  /// Label for the primary action.
  final String label;

  /// Optional refresh callback. If null, the refresh button is hidden.
  final VoidCallback? onRefresh;

  /// Whether a refresh is in progress (rotates the refresh icon).
  final bool isRefreshing;

  /// Optional hero tag to avoid conflicts when multiple FABs exist.
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (onRefresh != null) ...[
          SizedBox(
            width: 48,
            height: 48,
            child: FloatingActionButton.small(
              heroTag: heroTag == null ? null : '$heroTag-refresh',
              onPressed: isRefreshing ? null : onRefresh,
              backgroundColor: colorScheme.surfaceContainerHigh,
              foregroundColor: colorScheme.primary,
              elevation: AppElevation.level1,
              child: isRefreshing
                  ? const _RotatingRefreshIcon()
                  : const Icon(Icons.refresh),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        FloatingActionButton.extended(
          heroTag: heroTag,
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ],
    );
  }
}

class _RotatingRefreshIcon extends StatefulWidget {
  const _RotatingRefreshIcon();

  @override
  State<_RotatingRefreshIcon> createState() => _RotatingRefreshIconState();
}

class _RotatingRefreshIconState extends State<_RotatingRefreshIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: const Icon(Icons.refresh),
    );
  }
}
