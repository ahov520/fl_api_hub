/// Riverpod providers for the browser-plugin import feature.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/plugin_import_repository_impl.dart';
import '../../domain/repositories/plugin_import_repository.dart';
import 'backup_providers.dart';
import 'plugin_import_notifier.dart';
import 'plugin_import_state.dart';

/// Provides the [PluginImportRepository] implementation, reusing the backup
/// feature's Hive reader and file data source.
final pluginImportRepositoryProvider = Provider<PluginImportRepository>((ref) {
  return PluginImportRepositoryImpl(
    ref.watch(backupHiveReaderProvider),
    ref.watch(backupFileDataSourceProvider),
  );
});

/// Drives the plugin-import state machine for the UI to watch.
final pluginImportProvider =
    StateNotifierProvider<PluginImportNotifier, PluginImportState>((ref) {
      return PluginImportNotifier(ref.watch(pluginImportRepositoryProvider));
    });
