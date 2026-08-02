/// Application service that evaluates account balances against the user's
/// threshold and fires local notifications.
///
/// Wires into the Riverpod graph: it listens to [accountsProvider] and
/// re-evaluates whenever the account list (and therefore balances) changes.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notifications.dart';
import '../../../features/accounts/presentation/providers/accounts_providers.dart';
import '../../../features/settings/presentation/providers/notification_settings_providers.dart';

/// Tracks which accounts have already been alerted in the current session,
/// so that [NotificationSettings.onlyOncePerAccount] works as expected.
final _alertedAccountIdsProvider = StateProvider<Set<String>>((ref) => {});

/// Watches balances and triggers notifications when they cross the threshold.
///
/// Intended to be kept alive for the app's lifetime by listening in
/// `main.dart` (e.g. `ref.listen(balanceAlertServiceProvider, ...)`).
final balanceAlertServiceProvider = Provider<void>((ref) {
  ref.listen(accountsProvider, (previous, next) {
    final settings = ref.read(notificationSettingsProvider);
    if (!settings.enabled) return;

    final accounts = next.valueOrNull;
    if (accounts == null) return;

    final alertedIds = ref.read(_alertedAccountIdsProvider);

    for (final account in accounts) {
      if (account.excludeFromTotalBalance) continue;
      final balance = account.manualBalanceUsd ?? account.balance;
      if (balance == null) continue;

      final isLow = balance < settings.thresholdUsd;
      final alreadyAlerted = alertedIds.contains(account.id);

      if (isLow && (!settings.onlyOncePerAccount || !alreadyAlerted)) {
        // Mark before showing so a rapid second refresh doesn't duplicate.
        ref.read(_alertedAccountIdsProvider.notifier).update(
          (s) => {...s, account.id},
        );

        NotificationService.showBalanceAlert(
          id: account.id.hashCode,
          accountName: account.name,
          body:
              '当前余额 \$${balance.toStringAsFixed(2)},已低于阈值 '
              '\$${settings.thresholdUsd.toStringAsFixed(2)}',
        );
      } else if (!isLow && alreadyAlerted) {
        // Balance recovered — allow a future alert again.
        ref.read(_alertedAccountIdsProvider.notifier).update(
          (s) => s..remove(account.id),
        );
      }
    }
  });
});
