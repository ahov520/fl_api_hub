/// Notification settings entity for balance threshold alerts.
///
/// Persisted to Hive so the user's preference survives app restarts.
library;

/// User-configurable balance alert preferences.
class NotificationSettings {
  /// Whether balance alerts are enabled at all.
  final bool enabled;

  /// USD threshold below which an alert is triggered.
  final double thresholdUsd;

  /// When true, each account is only alerted once until its balance rises
  /// above the threshold again (prevents notification spam on every refresh).
  final bool onlyOncePerAccount;

  const NotificationSettings({
    this.enabled = false,
    this.thresholdUsd = 2.0,
    this.onlyOncePerAccount = true,
  });

  NotificationSettings copyWith({
    bool? enabled,
    double? thresholdUsd,
    bool? onlyOncePerAccount,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      thresholdUsd: thresholdUsd ?? this.thresholdUsd,
      onlyOncePerAccount: onlyOncePerAccount ?? this.onlyOncePerAccount,
    );
  }

  Map<String, dynamic> toMap() => {
    'enabled': enabled,
    'thresholdUsd': thresholdUsd,
    'onlyOncePerAccount': onlyOncePerAccount,
  };

  static NotificationSettings fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      enabled: map['enabled'] as bool? ?? false,
      thresholdUsd: (map['thresholdUsd'] as num?)?.toDouble() ?? 2.0,
      onlyOncePerAccount: map['onlyOncePerAccount'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationSettings &&
          enabled == other.enabled &&
          thresholdUsd == other.thresholdUsd &&
          onlyOncePerAccount == other.onlyOncePerAccount;

  @override
  int get hashCode => Object.hash(enabled, thresholdUsd, onlyOncePerAccount);
}
