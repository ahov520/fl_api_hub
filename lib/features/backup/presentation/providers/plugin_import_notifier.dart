/// StateNotifier that drives the browser-plugin import flow.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/result/result.dart';
import '../../domain/repositories/plugin_import_repository.dart';
import 'plugin_import_state.dart';

class PluginImportNotifier extends StateNotifier<PluginImportState> {
  final PluginImportRepository _repository;

  PluginImportNotifier(this._repository) : super(const PluginImportIdle());

  /// Imports the plugin export at [filePath], transitioning through
  /// in-progress and then either completed or error.
  Future<void> importFromFile(String filePath) async {
    state = const PluginImportInProgress();

    final result = await _repository.importFromFile(filePath);

    if (!mounted) return;

    state = result.when(
      onSuccess: (summary) => PluginImportCompleted(summary),
      onFailure: (e) => PluginImportError(e),
    );
  }

  /// Resets state back to idle (called after the result page is dismissed).
  void reset() {
    state = const PluginImportIdle();
  }
}
