/// Abstract interface for importing All-API-Hub browser-plugin export files.
library;

import '../../../../core/result/result.dart';
import '../entities/plugin_import_summary.dart';

/// Contract for importing account/tag data from a browser-plugin export file.
abstract class PluginImportRepository {
  /// Parses the plugin export at [filePath], merges it into local storage
  /// (append-only — existing local accounts/tags are never overwritten) and
  /// returns a [PluginImportSummary] describing the counts.
  ///
  /// Returns a [Failure] carrying a user-facing message when the file is not a
  /// valid All-API-Hub export; in that case nothing is written to storage.
  Future<Result<PluginImportSummary>> importFromFile(String filePath);
}
