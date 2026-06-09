/// Maps a [PluginSiteAccount] into this project's persistable account map.
///
/// The output map is intentionally key-compatible with [AccountMapper.toMap]
/// so it can be written straight into the `accounts` Hive box and later
/// rehydrated by [AccountMapper.fromMap]. See the field-mapping contract in
/// the task design (§3.1) — the notable rules are:
///   * `disabled` is *inverted* into `enabled`;
///   * cookie accounts take their token from `cookieAuth.sessionCookie`
///     (leading `session=` stripped), others from `account_info.access_token`;
///   * balance is `quota / kDefaultQuotaPerUnit` — `quota` is already the
///     *remaining* balance, so nothing is subtracted (see the quota/balance
///     contract spec to avoid the historical double-deduction bug).
library;

import '../../../../core/config/app_defaults.dart';
import '../../../../core/network/site_type.dart';
import 'plugin_export_dto.dart';

/// Leading marker stripped from cookie session strings before storage.
///
/// The plugin stores the full cookie pair (`session=<value>`), but this
/// project's auth interceptor re-adds the `session=` prefix at request time,
/// so only the raw value is persisted.
const _kSessionCookiePrefix = 'session=';

/// Converts plugin accounts into account-box maps.
class PluginAccountMapper {
  const PluginAccountMapper._();

  /// Builds a persistable account map from a plugin account.
  ///
  /// [newId] is supplied by the caller (the merger generates a fresh UUID per
  /// account) so this function stays pure and deterministic for tests.
  /// [orderIndex] is the account's position in the merged ordering and
  /// [baseSortOrder] is the largest existing local `sortOrder`; the new record
  /// is appended after local accounts via `baseSortOrder + 1 + orderIndex`.
  /// [tagIdRemap] maps plugin tag ids to their resolved local tag ids; any
  /// plugin tag id absent from the map is dropped so the result only ever
  /// references tags that actually exist locally.
  static Map<String, dynamic> toMap(
    PluginSiteAccount acc, {
    required int orderIndex,
    required int baseSortOrder,
    required Map<String, String> tagIdRemap,
    required String newId,
  }) {
    final isCookie = acc.authType == 'cookie';
    return {
      'id': newId,
      'name': acc.siteName,
      'baseUrl': acc.siteUrl,
      'siteType': _resolveSiteType(acc.siteType),
      'authType': _resolveAuthType(acc.authType),
      'accessToken': _resolveAccessToken(acc, isCookie),
      'enabled': !(acc.disabled ?? false),
      'notes': acc.notes ?? '',
      'balance': _resolveBalance(acc.accountInfo?.quota),
      'username': acc.accountInfo?.username ?? '',
      'userId': _resolveUserId(acc.accountInfo?.id),
      'exchangeRate': acc.exchangeRate ?? kDefaultUsdToCnyRate,
      'manualBalanceUsd': _resolveManualBalance(acc.manualBalanceUsd),
      'excludeFromTotalBalance': acc.excludeFromTotalBalance ?? false,
      'tagIds': _remapTagIds(acc.tagIds, tagIdRemap),
      'checkIn': _resolveCheckIn(acc.checkIn),
      'redemptionUrl': _resolveRedemptionUrl(acc.checkIn),
      'createdAt': millisToIso8601(acc.createdAt),
      'updatedAt': millisToIso8601(acc.updatedAt),
      'sortOrder': baseSortOrder + 1 + orderIndex,
      'proxyMode': 'followGlobal',
      'proxyConfig': null,
    };
  }

  /// Converts an epoch-millisecond timestamp into an ISO-8601 string.
  ///
  /// Falls back to the current time when [ms] is null so the produced map
  /// always carries a parseable `createdAt` / `updatedAt`
  /// ([AccountMapper.fromMap] / `TagMapper.fromMap` call `DateTime.parse`,
  /// which rejects null). Shared with the tag mapping in the import merger.
  static String millisToIso8601(int? ms) {
    if (ms == null) return DateTime.now().toIso8601String();
    return DateTime.fromMillisecondsSinceEpoch(ms).toIso8601String();
  }

  /// Maps the plugin `site_type` string to a known [SiteType] value, falling
  /// back to `SiteType.unknown` for unrecognized backends.
  static String _resolveSiteType(String? raw) {
    if (raw == null) return SiteType.unknown.value;
    try {
      return SiteType.fromValue(raw).value;
    } on ArgumentError {
      return SiteType.unknown.value;
    }
  }

  /// Maps the plugin `authType` string (`access_token` / `cookie`) to this
  /// project's [AuthType] enum name. Anything other than `cookie` defaults to
  /// access-token auth.
  static String _resolveAuthType(String? raw) {
    if (raw == 'cookie') return AuthType.cookie.name;
    return AuthType.accessToken.name;
  }

  /// Resolves the stored access token.
  ///
  /// Cookie accounts use `cookieAuth.sessionCookie` with the leading
  /// `session=` prefix stripped (the interceptor re-adds it); other accounts
  /// use `account_info.access_token`.
  static String? _resolveAccessToken(PluginSiteAccount acc, bool isCookie) {
    if (isCookie) {
      final cookie = acc.sessionCookie;
      if (cookie == null) return null;
      return cookie.startsWith(_kSessionCookiePrefix)
          ? cookie.substring(_kSessionCookiePrefix.length)
          : cookie;
    }
    return acc.accountInfo?.accessToken;
  }

  /// Derives the cached USD balance from the remaining quota.
  ///
  /// `quota` is already the remaining balance in token units, so it is divided
  /// by [kDefaultQuotaPerUnit] without subtracting any historical usage.
  static double? _resolveBalance(num? quota) {
    if (quota == null) return null;
    return quota / kDefaultQuotaPerUnit;
  }

  /// Parses `account_info.id` into an int, using `-1` (the account user-id
  /// sentinel) when missing or unparseable.
  static int _resolveUserId(String? raw) {
    if (raw == null) return -1;
    return int.tryParse(raw.trim()) ?? -1;
  }

  /// Parses the manual-balance string: empty/blank → null, otherwise the
  /// parsed double (or null when unparseable).
  static double? _resolveManualBalance(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  /// Remaps plugin tag ids onto resolved local tag ids, dropping any id that
  /// is not present in [tagIdRemap] and deduplicating the result (two plugin
  /// tags can collapse onto the same local id) while preserving order.
  static List<String> _remapTagIds(
    List<String> tagIds,
    Map<String, String> tagIdRemap,
  ) {
    final seen = <String>{};
    final result = <String>[];
    for (final id in tagIds) {
      final mapped = tagIdRemap[id];
      if (mapped != null && seen.add(mapped)) {
        result.add(mapped);
      }
    }
    return result;
  }

  /// Flattens the nested check-in block into this project's
  /// `{autoCheckInEnabled, customCheckInUrl}` shape; an empty custom URL
  /// becomes null.
  static Map<String, dynamic> _resolveCheckIn(PluginCheckIn? checkIn) {
    final url = checkIn?.customCheckInUrl;
    return {
      'autoCheckInEnabled': checkIn?.autoCheckInEnabled ?? false,
      'customCheckInUrl': (url == null || url.isEmpty) ? null : url,
    };
  }

  /// Maps `customCheckIn.redeemUrl` to `redemptionUrl`; empty → null.
  static String? _resolveRedemptionUrl(PluginCheckIn? checkIn) {
    final url = checkIn?.redeemUrl;
    if (url == null || url.isEmpty) return null;
    return url;
  }
}
