/// Local notification service for balance alerts.
///
/// Wraps `flutter_local_notifications` and owns the Android notification
/// channel, permission request, and the simple show/cancel API used by the
/// balance alert service.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notification channel for balance threshold alerts.
const _balanceChannelId = 'balance_alerts';
const _balanceChannelName = '余额提醒';
const _balanceChannelDescription = '当账号余额低于设定阈值时发送提醒';

/// Centralised local-notification entry point.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Initializes the plugin and requests the Android 13+ notification
  /// permission. Safe to call multiple times.
  static Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);

    // Android 13 (API 33) requires a runtime permission for notifications.
    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();

    _initialized = true;
    debugPrint('NotificationService initialized');
  }

  /// Shows a balance-low alert notification.
  ///
  /// [accountName] is shown in the title; [body] should contain the current
  /// balance and threshold details. [id] should be stable per account so
  /// repeated alerts replace the previous one instead of stacking.
  static Future<void> showBalanceAlert({
    required int id,
    required String accountName,
    required String body,
  }) async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      _balanceChannelId,
      _balanceChannelName,
      channelDescription: _balanceChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ticker: '余额不足',
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(id, '$accountName 余额不足', body, details);
  }

  /// Cancels a previously shown alert.
  static Future<void> cancel(int id) => _plugin.cancel(id);
}
