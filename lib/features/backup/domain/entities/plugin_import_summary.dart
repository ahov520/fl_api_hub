/// Result summary of a browser-plugin data import.
///
/// Reports the four user-facing counts shown on the import result page after a
/// merge completes. All counts default to zero so a "nothing happened" summary
/// is expressible.
library;

/// Immutable counts describing the outcome of a plugin import.
class PluginImportSummary {
  /// Number of accounts newly written to the local store.
  final int accountsImported;

  /// Number of accounts skipped because a local account with the same
  /// `baseUrl + username` already existed (local copy is preserved).
  final int accountsSkipped;

  /// Number of tags newly created locally.
  final int tagsImported;

  /// Number of plugin tags that matched an existing local tag (by
  /// case-insensitive name) and reused the local tag id instead.
  final int tagsReused;

  const PluginImportSummary({
    this.accountsImported = 0,
    this.accountsSkipped = 0,
    this.tagsImported = 0,
    this.tagsReused = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PluginImportSummary &&
          accountsImported == other.accountsImported &&
          accountsSkipped == other.accountsSkipped &&
          tagsImported == other.tagsImported &&
          tagsReused == other.tagsReused;

  @override
  int get hashCode =>
      Object.hash(accountsImported, accountsSkipped, tagsImported, tagsReused);

  @override
  String toString() =>
      'PluginImportSummary(accountsImported: $accountsImported, '
      'accountsSkipped: $accountsSkipped, tagsImported: $tagsImported, '
      'tagsReused: $tagsReused)';
}
