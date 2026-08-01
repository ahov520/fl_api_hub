/// Model list & cross-site price comparison page.
///
/// Shows every model offered by any enabled account, with a search bar and
/// expandable rows revealing each site's effective price, highlighting the
/// cheapest. Mirrors all-api-hub's price-comparison view.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../providers/models_providers.dart';
import '../widgets/model_comparison_tile.dart';

class ModelsPage extends ConsumerWidget {
  const ModelsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(filteredModelComparisonsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('模型比价'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SearchBar(
              hintText: '搜索模型或站点…',
              leading: const Icon(Icons.search),
              onChanged: (q) =>
                  ref.read(modelSearchQueryProvider.notifier).state = q,
            ),
          ),
        ),
      ),
      body: switch (asyncList) {
        AsyncLoading() => const AppLoadingState(message: '正在拉取各站价格…'),
        AsyncError(:final error) => AppErrorState(
          message: '加载模型价格失败：$error',
          onRetry: () => ref.invalidate(modelComparisonsProvider),
        ),
        AsyncData(:final value) => _buildBody(ref, value),
        _ => const AppLoadingState(),
      },
    );
  }

  Widget _buildBody(WidgetRef ref, List<dynamic> comparisons) {
    if (comparisons.isEmpty) {
      return const AppEmptyState(
        icon: Icons.price_change_outlined,
        message: '暂无可比价的模型\n支持定价接口的站点会在这里聚合',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(modelComparisonsProvider),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: comparisons.length,
        itemBuilder: (context, index) =>
            ModelComparisonTile(comparison: comparisons[index]),
      ),
    );
  }
}
