/// Remote data source for model pricing operations.
///
/// Thin delegation layer that forwards calls to the appropriate [SiteAdapter],
/// mirroring the other features' remote data sources.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_request.dart';
import '../../../../core/network/dto/model_pricing_dto.dart';
import '../../../../core/network/site_adapter.dart';
import '../../../../core/network/site_adapter_provider.dart';
import '../../../../core/network/site_type.dart';
import '../../../../core/result/result.dart';

/// Remote data source for model pricing operations.
class ModelsRemoteDataSource {
  final SiteAdapter _adapter;

  ModelsRemoteDataSource(this._adapter);

  /// Fetches the pricing catalog for a single account via its site adapter.
  Future<Result<ModelPricingResponseDto>> fetchModelPricing(
    ApiRequest request,
  ) => _adapter.fetchModelPricing(request);
}

/// Provider for [ModelsRemoteDataSource], parameterized by [SiteType].
final modelsRemoteDataSourceProvider =
    Provider.family<ModelsRemoteDataSource, SiteType>((ref, siteType) {
      final adapter = ref.watch(siteAdapterForTypeProvider(siteType));
      return ModelsRemoteDataSource(adapter);
    });
