/// State machine for the browser-plugin import flow.
library;

import '../../../../core/error/app_exception.dart';
import '../../domain/entities/plugin_import_summary.dart';

/// Sealed state for the plugin-import feature.
sealed class PluginImportState {
  const PluginImportState();
}

/// Idle — no import in progress.
class PluginImportIdle extends PluginImportState {
  const PluginImportIdle();
}

/// An import is running (parse + merge + write).
class PluginImportInProgress extends PluginImportState {
  const PluginImportInProgress();
}

/// Import finished successfully with the resulting [summary].
class PluginImportCompleted extends PluginImportState {
  final PluginImportSummary summary;
  const PluginImportCompleted(this.summary);
}

/// Import failed with an error.
class PluginImportError extends PluginImportState {
  final AppException exception;
  const PluginImportError(this.exception);
}
