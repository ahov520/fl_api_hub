/// Result summary page shown after a browser-plugin import completes.
///
/// Mirrors [RestoreResultPage]'s visual style but is an ordinary poppable page:
/// plugin import is append-only, so — unlike a full restore — it does not force
/// an app restart.
library;

import 'package:flutter/material.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../domain/entities/plugin_import_summary.dart';

class PluginImportResultPage extends StatelessWidget {
  final PluginImportSummary summary;

  const PluginImportResultPage({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('导入结果')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: colors.primary),
          const SizedBox(height: AppSpacing.md),
          Text(
            '导入完成',
            style: theme.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '已合并追加到本地数据，未覆盖任何既有账号或标签',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.secondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  _ResultRow(label: '新增账号', count: summary.accountsImported),
                  _ResultRow(label: '跳过账号', count: summary.accountsSkipped),
                  _ResultRow(label: '新增标签', count: summary.tagsImported),
                  _ResultRow(label: '复用标签', count: summary.tagsReused),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final int count;

  const _ResultRow({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            '$count 个',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
