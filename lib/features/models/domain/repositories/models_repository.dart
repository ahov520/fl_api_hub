/// Repository contract for the model catalog and price comparison.
///
/// Aggregates `/api/pricing` from every enabled account and produces
/// per-model cross-site comparisons. All methods return [Result] to enforce
/// explicit error handling.
library;

import '../../../../core/result/result.dart';
import '../entities/model_comparison.dart';

/// Abstract repository for model pricing aggregation.
abstract class ModelsRepository {
  /// Fetches pricing from every enabled account and groups offers by model
  /// name. Accounts that fail or are unsupported are skipped silently.
  ///
  /// The returned list is sorted by model name; each [ModelComparison]'s
  /// offers are sorted cheapest-first.
  Future<Result<List<ModelComparison>>> fetchComparisons();
}
