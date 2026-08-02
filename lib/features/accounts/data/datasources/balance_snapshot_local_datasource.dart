/// Local data source for [BalanceSnapshot] entities.
///
/// Snapshots are stored in a dedicated Hive box and pruned per-account to
/// bound storage growth, mirroring the check-in result retention pattern.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../../domain/entities/balance_snapshot.dart';
import '../models/balance_snapshot_mapper.dart';

/// Box name for balance snapshot storage.
const _snapshotBoxName = 'balance_snapshots';

/// Per-account retention cap for [BalanceSnapshot] records.
///
/// At most this many snapshots are kept per `accountId`. Writes beyond the
/// cap cause the oldest records (by `capturedAt`) to be deleted automatically.
const kBalanceSnapshotsCapPerAccount = 90;

/// Local CRUD operations for balance snapshots.
class BalanceSnapshotLocalDataSource {
  final Box _box;

  BalanceSnapshotLocalDataSource(this._box);

  /// Persists a [snapshot] to the local box.
  ///
  /// After writing, automatically prunes records for the same `accountId`
  /// down to [kBalanceSnapshotsCapPerAccount] by deleting the oldest entries
  /// (by `capturedAt`).
  Future<void> saveSnapshot(BalanceSnapshot snapshot) async {
    await _box.put(snapshot.id, BalanceSnapshotMapper.toMap(snapshot));
    await pruneAccountSnapshots(snapshot.accountId);
  }

  /// Returns all snapshots for a given [accountId], newest first.
  List<BalanceSnapshot> getSnapshotsByAccountId(String accountId) {
    final snapshots = _box.values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((map) => map['accountId'] == accountId)
        .map(BalanceSnapshotMapper.fromMap)
        .toList();
    snapshots.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return snapshots;
  }

  /// Returns the most recent snapshot for [accountId], or `null`.
  BalanceSnapshot? getLatestSnapshot(String accountId) {
    final snapshots = getSnapshotsByAccountId(accountId);
    return snapshots.isEmpty ? null : snapshots.first;
  }

  /// Returns snapshots from the last [days] days, grouped by calendar day.
  ///
  /// For each day, the *latest* snapshot of that day is used. The result is
  /// a map of `DateTime(day)` → total balance across non-excluded accounts.
  Map<DateTime, double> getDailyTotals({
    required int days,
    required Set<String> excludedAccountIds,
  }) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final byDay = <DateTime, Map<String, BalanceSnapshot>>{};

    for (final raw in _box.values) {
      final map = Map<String, dynamic>.from(raw as Map);
      if (excludedAccountIds.contains(map['accountId'])) continue;
      final snapshot = BalanceSnapshotMapper.fromMap(map);
      if (snapshot.capturedAt.isBefore(cutoff)) continue;
      final day = DateTime(
        snapshot.capturedAt.year,
        snapshot.capturedAt.month,
        snapshot.capturedAt.day,
      );
      byDay.putIfAbsent(day, () => {})[snapshot.accountId] = snapshot;
    }

    return {
      for (final entry in byDay.entries)
        entry.key: entry.value.values.fold(
          0.0,
          (sum, s) => sum + s.balanceUsd,
        ),
    };
  }

  /// Deletes all snapshots belonging to [accountId].
  Future<void> deleteSnapshotsByAccountId(String accountId) async {
    final keysToDelete = <dynamic>[];
    for (final entry in _box.toMap().entries) {
      final map = Map<String, dynamic>.from(entry.value as Map);
      if (map['accountId'] == accountId) keysToDelete.add(entry.key);
    }
    await _box.deleteAll(keysToDelete);
  }

  /// Trims snapshots for [accountId] to [kBalanceSnapshotsCapPerAccount].
  Future<void> pruneAccountSnapshots(String accountId) async {
    final snapshots = getSnapshotsByAccountId(accountId);
    if (snapshots.length <= kBalanceSnapshotsCapPerAccount) return;
    final toDelete = snapshots.sublist(kBalanceSnapshotsCapPerAccount);
    await _box.deleteAll(toDelete.map((s) => s.id));
  }
}

/// Riverpod provider for [BalanceSnapshotLocalDataSource].
final balanceSnapshotLocalDataSourceProvider =
    Provider<BalanceSnapshotLocalDataSource>((ref) {
      final box = Hive.box(_snapshotBoxName);
      return BalanceSnapshotLocalDataSource(box);
    });
