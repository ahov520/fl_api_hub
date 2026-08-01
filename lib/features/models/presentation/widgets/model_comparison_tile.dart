/// Expansion tile for one model's cross-site price comparison.
///
/// Collapsed: model name, site count, and the best (cheapest) price with its
/// site. Expanded: every account's offer sorted cheapest-first, highlighting
/// the best deal.
library;

import 'package:flutter/material.dart';

import '../../domain/entities/model_comparison.dart';

/// Displays one [ModelComparison] as an expandable comparison row.
class ModelComparisonTile extends StatelessWidget {
  final ModelComparison comparison;

  const ModelComparisonTile({super.key, required this.comparison});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final best = comparison.bestOffer;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.secondaryContainer,
          child: Icon(
            Icons.smart_toy_outlined,
            color: colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(
          comparison.modelName,
          style: theme.textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${comparison.siteCount} 个站点'
          '${best != null ? ' · 最低 ${_formatPrice(best)} @ ${best.accountName}' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          const Divider(height: 1),
          for (var i = 0; i < comparison.offers.length; i++)
            _OfferRow(offer: comparison.offers[i], isBest: i == 0),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  static String _formatPrice(ModelOffer offer) {
    final price = offer.priceUsd;
    if (price == null) return '无价';
    final unit = offer.billing == ModelBilling.perCall ? '/次' : '/1M';
    return '\$${price.toStringAsFixed(price < 1 ? 4 : 2)}$unit';
  }
}

/// A single account's offer row inside the expansion.
class _OfferRow extends StatelessWidget {
  final ModelOffer offer;
  final bool isBest;

  const _OfferRow({required this.offer, required this.isBest});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      dense: true,
      leading: isBest
          ? Icon(Icons.emoji_events, color: colorScheme.primary, size: 20)
          : const SizedBox(width: 20),
      title: Text(offer.accountName, style: theme.textTheme.bodyLarge),
      subtitle: Text(
        [
          if (offer.group != null) '分组 ${offer.group}',
          offer.billing == ModelBilling.perCall ? '按次计费' : '按量计费',
          if (offer.completionRatio != 1)
            '输出×${offer.completionRatio.toStringAsFixed(2)}',
        ].join(' · '),
      ),
      trailing: Text(
        offer.hasPrice ? ModelComparisonTile._formatPrice(offer) : '无可用价格',
        style: theme.textTheme.titleSmall?.copyWith(
          color: isBest ? colorScheme.primary : colorScheme.onSurface,
          fontWeight: isBest ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
