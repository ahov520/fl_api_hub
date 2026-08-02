import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../app/theme/design_tokens.dart';

/// Shared skeleton placeholders shown while content is loading.
///
/// Uses the `shimmer` package to render a subtle animated gradient over
/// placeholder boxes that mimic the real list/card layout.
abstract final class AppSkeleton {
  /// A single rounded rectangle placeholder.
  static Widget box({
    double width = double.infinity,
    double height = 16,
    double radius = AppRadius.sm,
  }) {
    return Builder(
      builder: (context) {
        final base = Theme.of(context).colorScheme.surfaceContainerHighest;
        final highlight = Theme.of(context).colorScheme.surface;
        return Shimmer.fromColors(
          baseColor: base,
          highlightColor: highlight,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: base,
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        );
      },
    );
  }

  /// Placeholder matching a typical account/key card.
  static Widget card() {
    return Builder(
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  box(width: 40, height: 40, radius: AppRadius.md),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        box(width: 120, height: 18),
                        const SizedBox(height: AppSpacing.xs),
                        box(width: 80, height: 14),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              box(height: 14),
              const SizedBox(height: AppSpacing.xs),
              box(width: 200, height: 14),
            ],
          ),
        );
      },
    );
  }

  /// A column of [count] card placeholders.
  static Widget list({int count = 4}) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, _) => card(),
    );
  }
}
