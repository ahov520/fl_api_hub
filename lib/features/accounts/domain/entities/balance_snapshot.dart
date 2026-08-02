/// Balance snapshot entity recording an account's balance at a point in time.
///
/// Each successful account sync produces a [BalanceSnapshot] so that the
/// app can render 7-day trend charts and compute consumption deltas.
library;

/// A single balance observation for an [Account].
class BalanceSnapshot {
  /// Unique identifier (UUID v4).
  final String id;

  /// Foreign key to the [Account] this snapshot belongs to.
  final String accountId;

  /// USD balance reported at capture time.
  final double balanceUsd;

  /// Quota already consumed at capture time (raw upstream units).
  ///
  /// May be `null` when the upstream site does not report `used_quota`.
  final double? usedQuota;

  /// Timestamp when this snapshot was captured.
  final DateTime capturedAt;

  const BalanceSnapshot({
    required this.id,
    required this.accountId,
    required this.balanceUsd,
    this.usedQuota,
    required this.capturedAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BalanceSnapshot && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'BalanceSnapshot(id: $id, accountId: $accountId, balanceUsd: $balanceUsd)';
}
