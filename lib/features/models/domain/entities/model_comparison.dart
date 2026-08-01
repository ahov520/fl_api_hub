/// Domain entities for the model catalog and cross-site price comparison.
///
/// A [ModelOffer] is one site's price for one model; a [ModelComparison]
/// aggregates every offer for a given model name across all accounts and
/// marks the cheapest, mirroring all-api-hub's price-comparison feature.
library;

/// Billing mode carried from the pricing DTO.
enum ModelBilling {
  /// Billed by token usage.
  token,

  /// Billed per request.
  perCall,
}

/// One account's offer for a single model.
class ModelOffer {
  /// Model identifier (e.g. `gpt-4o`).
  final String modelName;

  /// Source account id.
  final String accountId;

  /// Display name of the source site.
  final String accountName;

  /// Billing mode for this offer.
  final ModelBilling billing;

  /// Effective input price in USD per 1M tokens (token-billed) or per
  /// request (per-call). `null` when no usable group price could be derived.
  final double? priceUsd;

  /// The group whose ratio produced [priceUsd], when known.
  final String? group;

  /// Output price ratio relative to input (informational).
  final double completionRatio;

  const ModelOffer({
    required this.modelName,
    required this.accountId,
    required this.accountName,
    required this.billing,
    required this.priceUsd,
    required this.group,
    required this.completionRatio,
  });

  /// Whether this offer has a usable price.
  bool get hasPrice => priceUsd != null;
}

/// Aggregated comparison for a single model across every account.
class ModelComparison {
  /// Model identifier shared by all offers.
  final String modelName;

  /// Every account's offer for this model (sorted cheapest first).
  final List<ModelOffer> offers;

  const ModelComparison({required this.modelName, required this.offers});

  /// The cheapest offer with a usable price, or `null` if none.
  ModelOffer? get bestOffer {
    for (final offer in offers) {
      if (offer.hasPrice) return offer;
    }
    return null;
  }

  /// The lowest usable price across all offers, or `null`.
  double? get bestPrice => bestOffer?.priceUsd;

  /// Number of accounts offering this model.
  int get siteCount => offers.length;
}
