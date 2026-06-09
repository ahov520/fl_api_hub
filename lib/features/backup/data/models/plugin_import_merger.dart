/// Pure merge logic for importing plugin export data into the local store.
///
/// Given the *raw* local account/tag maps (as read by `BackupHiveReader`) and a
/// parsed [PluginExport], this produces an incremental [BackupData] (containing
/// only the new accounts and tags) plus a [PluginImportSummary]. It performs no
/// I/O, so it is safe to run inside `Isolate.run` and is fully unit-testable.
///
/// Merge rules (task design §4):
///   * Tags dedupe by case-insensitive name — an existing local tag is reused
///     (its id wins), otherwise the plugin tag is added with its own id.
///   * Accounts dedupe by the business key `baseUrl + ' ' + username` —
///     duplicates are skipped so user edits to a local account are never
///     overwritten. New accounts get a fresh UUID and are appended after the
///     largest existing local `sortOrder`.
library;

import 'package:uuid/uuid.dart';

import '../../domain/entities/plugin_import_summary.dart';
import 'backup_data.dart';
import 'plugin_account_mapper.dart';
import 'plugin_export_dto.dart';

/// Outcome of [PluginImportMerger.merge]: the data to append and the counts.
typedef PluginMergeResult = ({
  BackupData resolved,
  PluginImportSummary summary,
});

/// Computes the incremental account/tag data to append on import.
class PluginImportMerger {
  const PluginImportMerger._();

  /// Merges [export] against the existing [localAccounts] / [localTags].
  ///
  /// Both local lists are the raw maps produced by `AccountMapper.toMap` /
  /// `TagMapper.toMap` (i.e. `BackupHiveReader.readAll()` output). [generateId]
  /// defaults to a real v4 UUID generator but can be overridden for
  /// deterministic tests.
  static PluginMergeResult merge(
    PluginExport export, {
    required List<Map<String, dynamic>> localAccounts,
    required List<Map<String, dynamic>> localTags,
    String Function()? generateId,
  }) {
    final newId = generateId ?? const Uuid().v4;

    final tagOutcome = _mergeTags(export.tagStore, localTags);
    final accountOutcome = _mergeAccounts(
      export,
      localAccounts: localAccounts,
      tagIdRemap: tagOutcome.tagIdRemap,
      newId: newId,
    );

    final resolved = BackupData(
      accounts: accountOutcome.newAccounts,
      keys: const [],
      tags: tagOutcome.newTags,
      checkInTasks: const [],
      checkInResults: const [],
      schedulerConfig: const {},
      appData: const {},
    );

    final summary = PluginImportSummary(
      accountsImported: accountOutcome.imported,
      accountsSkipped: accountOutcome.skipped,
      tagsImported: tagOutcome.imported,
      tagsReused: tagOutcome.reused,
    );

    return (resolved: resolved, summary: summary);
  }

  // -- Tags -----------------------------------------------------------------

  static _TagOutcome _mergeTags(
    List<PluginTag> pluginTags,
    List<Map<String, dynamic>> localTags,
  ) {
    // Case/whitespace-insensitive name -> local tag id.
    final localTagByName = <String, String>{};
    for (final tag in localTags) {
      final name = (tag['name'] as String?)?.trim().toLowerCase();
      final id = tag['id'] as String?;
      if (name != null && name.isNotEmpty && id != null) {
        localTagByName.putIfAbsent(name, () => id);
      }
    }

    final tagIdRemap = <String, String>{};
    final newTags = <Map<String, dynamic>>[];
    var imported = 0;
    var reused = 0;

    for (final pTag in pluginTags) {
      final key = pTag.name.trim().toLowerCase();
      final existingId = localTagByName[key];
      if (existingId != null) {
        // Reuse the local tag; remap the plugin id onto it.
        tagIdRemap[pTag.id] = existingId;
        reused++;
      } else {
        // New tag: keep the plugin id and register it for later same-file
        // duplicates so a repeated name collapses onto this one.
        newTags.add(_tagToMap(pTag));
        tagIdRemap[pTag.id] = pTag.id;
        localTagByName[key] = pTag.id;
        imported++;
      }
    }

    return _TagOutcome(
      tagIdRemap: tagIdRemap,
      newTags: newTags,
      imported: imported,
      reused: reused,
    );
  }

  /// Serializes a plugin tag into this project's `TagMapper.toMap` shape.
  static Map<String, dynamic> _tagToMap(PluginTag tag) => {
    'id': tag.id,
    'name': tag.name,
    'createdAt': PluginAccountMapper.millisToIso8601(tag.createdAt),
    'updatedAt': PluginAccountMapper.millisToIso8601(tag.updatedAt),
  };

  // -- Accounts -------------------------------------------------------------

  static _AccountOutcome _mergeAccounts(
    PluginExport export, {
    required List<Map<String, dynamic>> localAccounts,
    required Map<String, String> tagIdRemap,
    required String Function() newId,
  }) {
    final localKeys = <String>{};
    var localMaxSortOrder = 0;
    for (final acc in localAccounts) {
      localKeys.add(_businessKey(acc['baseUrl'], acc['username']));
      final sortOrder = (acc['sortOrder'] as num?)?.toInt() ?? 0;
      if (sortOrder > localMaxSortOrder) localMaxSortOrder = sortOrder;
    }

    final ordered = _orderAccounts(export.accounts, export.orderedAccountIds);

    final newAccounts = <Map<String, dynamic>>[];
    var imported = 0;
    var skipped = 0;

    // `orderIndex` is the position within the ordered list (it advances even
    // for skipped accounts), preserving the relative order of imported ones.
    for (var orderIndex = 0; orderIndex < ordered.length; orderIndex++) {
      final pAcc = ordered[orderIndex];
      final key = _businessKey(pAcc.siteUrl, pAcc.accountInfo?.username);
      if (localKeys.contains(key)) {
        skipped++;
        continue;
      }
      newAccounts.add(
        PluginAccountMapper.toMap(
          pAcc,
          orderIndex: orderIndex,
          baseSortOrder: localMaxSortOrder,
          tagIdRemap: tagIdRemap,
          newId: newId(),
        ),
      );
      // Guard against duplicates within the same export file.
      localKeys.add(key);
      imported++;
    }

    return _AccountOutcome(
      newAccounts: newAccounts,
      imported: imported,
      skipped: skipped,
    );
  }

  /// Builds the dedupe business key from a base URL and username.
  static String _businessKey(Object? baseUrl, Object? username) {
    final url = (baseUrl as String?) ?? '';
    final user = (username as String?) ?? '';
    return '$url $user';
  }

  /// Orders plugin accounts by [orderedIds] first, then appends any remaining
  /// accounts in their original order.
  static List<PluginSiteAccount> _orderAccounts(
    List<PluginSiteAccount> accounts,
    List<String> orderedIds,
  ) {
    final byId = {for (final a in accounts) a.id: a};
    final result = <PluginSiteAccount>[];
    final seen = <String>{};
    for (final id in orderedIds) {
      final acc = byId[id];
      if (acc != null && seen.add(id)) {
        result.add(acc);
      }
    }
    for (final acc in accounts) {
      if (seen.add(acc.id)) {
        result.add(acc);
      }
    }
    return result;
  }
}

/// Internal result of the tag-merge phase.
class _TagOutcome {
  final Map<String, String> tagIdRemap;
  final List<Map<String, dynamic>> newTags;
  final int imported;
  final int reused;

  const _TagOutcome({
    required this.tagIdRemap,
    required this.newTags,
    required this.imported,
    required this.reused,
  });
}

/// Internal result of the account-merge phase.
class _AccountOutcome {
  final List<Map<String, dynamic>> newAccounts;
  final int imported;
  final int skipped;

  const _AccountOutcome({
    required this.newAccounts,
    required this.imported,
    required this.skipped,
  });
}
