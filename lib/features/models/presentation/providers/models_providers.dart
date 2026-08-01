/// Riverpod providers for the Models (price comparison) feature.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/proxy_resolver.dart';
import '../../../../core/result/result.dart';
import '../../../accounts/presentation/providers/accounts_providers.dart';
import '../../../settings/data/providers/global_proxy_providers.dart';
import '../../data/datasources/models_remote_datasource.dart';
import '../../data/repositories/models_repository_impl.dart';
import '../../domain/entities/model_comparison.dart';
import '../../domain/repositories/models_repository.dart';

/// Provides the [ModelsRepository] implementation.
final modelsRepositoryProvider = Provider<ModelsRepository>((ref) {
  return ModelsRepositoryImpl(
    accountsRepository: ref.watch(accountsRepositoryProvider),
    remoteFor: (siteType) =>
        ref.watch(modelsRemoteDataSourceProvider(siteType)),
    proxyResolver: ref.watch(proxyResolverProvider),
    globalProxy: ref.watch(currentGlobalProxyProvider),
  );
});

/// Loads and caches the cross-site model comparisons.
final modelComparisonsProvider =
    FutureProvider.autoDispose<List<ModelComparison>>((ref) async {
      final repo = ref.watch(modelsRepositoryProvider);
      final result = await repo.fetchComparisons();
      return result.dataOrNull ?? const <ModelComparison>[];
    });

/// Free-text query used to filter the model list.
final modelSearchQueryProvider = StateProvider<String>((_) => '');

/// Comparisons filtered by the current search query (matches model name or
/// any offering site name).
final filteredModelComparisonsProvider =
    Provider.autoDispose<AsyncValue<List<ModelComparison>>>((ref) {
      final query = ref.watch(modelSearchQueryProvider).trim().toLowerCase();
      final asyncList = ref.watch(modelComparisonsProvider);
      if (query.isEmpty) return asyncList;

      return asyncList.whenData(
        (list) => list
            .where(
              (c) =>
                  c.modelName.toLowerCase().contains(query) ||
                  c.offers.any(
                    (o) => o.accountName.toLowerCase().contains(query),
                  ),
            )
            .toList(),
      );
    });
