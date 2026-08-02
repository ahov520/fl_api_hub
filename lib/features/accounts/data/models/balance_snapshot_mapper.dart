/// Mapper for [BalanceSnapshot] domain entity.
///
/// Used by the local data source to serialize/deserialize snapshots for
/// Hive storage.
library;

import '../../domain/entities/balance_snapshot.dart';

/// Converts [BalanceSnapshot] entities to and from JSON-compatible maps.
class BalanceSnapshotMapper {
  const BalanceSnapshotMapper._();

  /// Serializes a [BalanceSnapshot] into a persistable map.
  static Map<String, dynamic> toMap(BalanceSnapshot snapshot) => {
    'id': snapshot.id,
    'accountId': snapshot.accountId,
    'balanceUsd': snapshot.balanceUsd,
    'usedQuota': snapshot.usedQuota,
    'capturedAt': snapshot.capturedAt.toIso8601String(),
  };

  /// Deserializes a map back into a [BalanceSnapshot].
  static BalanceSnapshot fromMap(Map<String, dynamic> map) {
    return BalanceSnapshot(
      id: map['id'] as String,
      accountId: map['accountId'] as String,
      balanceUsd: (map['balanceUsd'] as num).toDouble(),
      usedQuota: (map['usedQuota'] as num?)?.toDouble(),
      capturedAt: DateTime.parse(map['capturedAt'] as String),
    );
  }
}
