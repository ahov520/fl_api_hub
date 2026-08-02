/// Riverpod providers for balance snapshots and derived aggregate metrics.
///
/// Exposes the raw snapshot stream per account, plus app-wide totals used
/// by the dashboard trend card and the balance alert service.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/balance_snapshot_local_datasource.dart';
import '../../domain/entities/balance_snapshot.dart';
import 'accounts_providers.dart';

/// Watches snapshots for a single account, newest first.
final balanceSnapshotsProvider =
    StreamProvider.family<List<BalanceSnapshot>, String>((ref, accountId) {
      final ds = ref.watch(balanceSnapshotLocalDataSourceProvider);
      // Hive boxes don't offer a query stream; emit on any box change and
      // filter client-side. This is cheap at the cap of 90 records/account.
      return Stream.periodic(
        const Duration(seconds: 1),
        (_) => ds.getSnapshotsByAccountId(accountId),
      ).distinct((a, b) => a.length == b.length);
    });

/// Daily total USD balance over the last [days] days.
///
/// Accounts marked `excludeFromTotalBalance` are ignored. For each calendar
/// day the *latest* snapshot of that day is summed across included accounts.
final dailyBalanceTotalsProvider = Provider.family<Map<DateTime, double>, int>(
  (ref, days) {
    final accountsAsync = ref.watch(accountsProvider);
    final ds = ref.watch(balanceSnapshotLocalDataSourceProvider);

    final accounts = accountsAsync.valueOrNull ?? [];
    final excluded = {
      for (final a in accounts)
        if (a.excludeFromTotalBalance) a.id,
    };

    return ds.getDailyTotals(days: days, excludedAccountIds: excluded);
  },
);

/// Convenience provider for the 7-day dashboard chart.
final sevenDayBalanceTotalsProvider = Provider<Map<DateTime, double>>(
  (ref) => ref.watch(dailyBalanceTotalsProvider(7)),
);

/// Sum of the current cached balances for all included accounts.
final totalBalanceProvider = Provider<double?>((ref) {
  final accountsAsync = ref.watch(accountsProvider);
  final accounts = accountsAsync.valueOrNull;
  if (accounts == null || accounts.isEmpty) return null;

  var total = 0.0;
  var anyIncluded = false;
  for (final account in accounts) {
    if (account.excludeFromTotalBalance) continue;
    final balance = account.manualBalanceUsd ?? account.balance;
    if (balance == null) continue;
    total += balance;
    anyIncluded = true;
  }
  return anyIncluded ? total : null;
});

/// Total USD consumed today across all included accounts.
///
/// Computed as `max(0, latestBalanceBeforeToday - latestBalanceToday)` per
/// account, then summed. Returns `null` when no snapshots exist yet.
final todayConsumptionProvider = Provider<double?>((ref) {
  final accountsAsync = ref.watch(accountsProvider);
  final ds = ref.watch(balanceSnapshotLocalDataSourceProvider);
  final accounts = accountsAsync.valueOrNull;
  if (accounts == null || accounts.isEmpty) return null;

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);

  var total = 0.0;
  var anyData = false;

  for (final account in accounts) {
    if (account.excludeFromTotalBalance) continue;
    final snapshots = ds.getSnapshotsByAccountId(account.id);
    if (snapshots.isEmpty) continue;

    // Latest snapshot before today = opening balance.
    BalanceSnapshot? opening;
    BalanceSnapshot? latest;
    for (final s in snapshots) {
      if (latest == null || s.capturedAt.isAfter(latest.capturedAt)) {
        latest = s;
      }
      if (s.capturedAt.isBefore(todayStart)) {
        if (opening == null || s.capturedAt.isAfter(opening.capturedAt)) {
          opening = s;
        }
      }
    }

    if (opening != null && latest != null && latest != opening) {
      final consumed = opening.balanceUsd - latest.balanceUsd;
      if (consumed > 0) total += consumed;
      anyData = true;
    }
  }

  return anyData ? total : null;
});
