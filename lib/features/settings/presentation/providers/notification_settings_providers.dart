/// Riverpod providers for [NotificationSettings].
///
/// Persists changes to the `app_data` Hive box and exposes a reactive
/// [StateNotifier] for the settings UI and the balance alert service.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/hive_store.dart';
import '../../domain/entities/notification_settings.dart';

const _kSettingsKey = 'notification_settings';

/// Manages the user's balance-alert preferences.
class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  final KeyValueStore _store;

  NotificationSettingsNotifier(this._store)
    : super(const NotificationSettings()) {
    _load();
  }

  Future<void> _load() async {
    final raw = await _store.read<Map>(_kSettingsKey);
    if (raw != null) {
      state = NotificationSettings.fromMap(Map<String, dynamic>.from(raw));
    }
  }

  Future<void> _save() => _store.write(_kSettingsKey, state.toMap());

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await _save();
  }

  Future<void> setThresholdUsd(double thresholdUsd) async {
    state = state.copyWith(thresholdUsd: thresholdUsd);
    await _save();
  }

  Future<void> setOnlyOncePerAccount(bool onlyOncePerAccount) async {
    state = state.copyWith(onlyOncePerAccount: onlyOncePerAccount);
    await _save();
  }
}

/// Provider for the balance-alert settings.
final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
      (ref) => NotificationSettingsNotifier(ref.watch(keyValueStoreProvider)),
    );
