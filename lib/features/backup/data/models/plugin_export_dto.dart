/// DTOs for the All-API-Hub browser plugin export file (backup `version "2.0"`).
///
/// Two export flavors share this shape: the accounts-only export carries
/// `type "accounts"`, while the full-data export has no top-level `type` at
/// all — both nest the same `accounts` structure.
///
/// These are *parse-only* value objects: they mirror the plugin's JSON shape
/// closely enough to feed [PluginAccountMapper] and the import merger, while
/// tolerating missing/optional fields (different plugin builds omit different
/// keys). Mapping into this project's persistence shape happens later — these
/// classes deliberately do no business conversion.
library;

/// Top-level plugin export envelope.
///
/// Only the subset this project actually imports is modeled: the account list,
/// the manual ordering hint, and the global tag store. Bookmarks, deleted-entry
/// records and sync metadata are intentionally ignored.
class PluginExport {
  /// Backup format version (e.g. `"2.0"`). May be absent in odd exports.
  final String? version;

  /// Export time as a Unix millisecond timestamp.
  final int? timestamp;

  /// Backup discriminator (`"accounts"` for an accounts-only export). The
  /// full-data export omits this key entirely, so it carries no validation
  /// weight — kept only as parsed metadata.
  final String? type;

  /// Site accounts in their stored (unordered) form.
  final List<PluginSiteAccount> accounts;

  /// Manual ordering hint referencing [PluginSiteAccount.id] values.
  final List<String> orderedAccountIds;

  /// Flattened tag store (the values of `tagStore.tagsById`).
  final List<PluginTag> tagStore;

  const PluginExport({
    required this.version,
    required this.timestamp,
    required this.type,
    required this.accounts,
    required this.orderedAccountIds,
    required this.tagStore,
  });

  /// Parses and validates a decoded plugin export map.
  ///
  /// Throws a [FormatException] with a user-facing Chinese message when the
  /// payload is not a valid All-API-Hub export, i.e. when the nested
  /// `accounts.accounts` array is missing. `type` is deliberately not checked:
  /// the full-data export has no `type` key. This is the single validation
  /// gate — callers can treat any thrown [FormatException] as "not a plugin
  /// file" and abort with zero writes.
  factory PluginExport.fromJson(Map<String, dynamic> json) {
    final accountsConfig = json['accounts'];
    if (accountsConfig is! Map) {
      throw const FormatException('不是有效的 All-API-Hub 导出文件');
    }
    final rawAccounts = accountsConfig['accounts'];
    if (rawAccounts is! List) {
      throw const FormatException('不是有效的 All-API-Hub 导出文件');
    }

    final accounts = <PluginSiteAccount>[];
    for (final raw in rawAccounts) {
      if (raw is Map) {
        accounts.add(
          PluginSiteAccount.fromJson(Map<String, dynamic>.from(raw)),
        );
      }
    }

    final orderedRaw = accountsConfig['orderedAccountIds'];
    final orderedAccountIds = orderedRaw is List
        ? orderedRaw.whereType<String>().toList(growable: false)
        : const <String>[];

    final tagStore = <PluginTag>[];
    final rawTagStore = json['tagStore'];
    if (rawTagStore is Map) {
      final tagsById = rawTagStore['tagsById'];
      if (tagsById is Map) {
        for (final value in tagsById.values) {
          if (value is Map) {
            tagStore.add(PluginTag.fromJson(Map<String, dynamic>.from(value)));
          }
        }
      }
    }

    return PluginExport(
      version: json['version'] as String?,
      timestamp: (json['timestamp'] as num?)?.toInt(),
      type: json['type'] as String?,
      accounts: accounts,
      orderedAccountIds: orderedAccountIds,
      tagStore: tagStore,
    );
  }
}

/// A single plugin site account (`accounts.accounts[]`).
class PluginSiteAccount {
  /// Plugin-local id (e.g. `account_...`). Used only to honor
  /// `orderedAccountIds`; never persisted by this project.
  final String id;

  /// User-chosen display name (`site_name`).
  final String siteName;

  /// API base URL (`site_url`).
  final String siteUrl;

  /// Backend family string (`site_type`, e.g. `new-api` / `anyrouter`).
  final String? siteType;

  /// CNY-per-USD exchange rate (`exchange_rate`).
  final double? exchangeRate;

  /// Core account info block (`account_info`).
  final PluginAccountInfo? accountInfo;

  /// Creation timestamp in epoch milliseconds (`created_at`).
  final int? createdAt;

  /// Last-update timestamp in epoch milliseconds (`updated_at`).
  final int? updatedAt;

  /// Free-form notes.
  final String? notes;

  /// Referenced global tag ids (`tagIds`).
  final List<String> tagIds;

  /// Whether the account is disabled (`disabled`). Note: this is the inverse
  /// of this project's `enabled` flag.
  final bool? disabled;

  /// Whether to exclude from aggregate balance (`excludeFromTotalBalance`).
  final bool? excludeFromTotalBalance;

  /// Auth method string (`authType`): `"access_token"` or `"cookie"`.
  final String? authType;

  /// Session cookie value (`cookieAuth.sessionCookie`). Only present for
  /// cookie-auth accounts. May still carry a leading `session=` prefix.
  final String? sessionCookie;

  /// Check-in configuration block (`checkIn`).
  final PluginCheckIn? checkIn;

  /// User-locked manual balance as a raw string (`manualBalanceUsd`). Empty
  /// string means "not set".
  final String? manualBalanceUsd;

  const PluginSiteAccount({
    required this.id,
    required this.siteName,
    required this.siteUrl,
    required this.siteType,
    required this.exchangeRate,
    required this.accountInfo,
    required this.createdAt,
    required this.updatedAt,
    required this.notes,
    required this.tagIds,
    required this.disabled,
    required this.excludeFromTotalBalance,
    required this.authType,
    required this.sessionCookie,
    required this.checkIn,
    required this.manualBalanceUsd,
  });

  factory PluginSiteAccount.fromJson(Map<String, dynamic> json) {
    final rawInfo = json['account_info'];
    final rawCookieAuth = json['cookieAuth'];
    final rawCheckIn = json['checkIn'];
    final rawTagIds = json['tagIds'];

    return PluginSiteAccount(
      id: (json['id'] as String?) ?? '',
      siteName: (json['site_name'] as String?) ?? '',
      siteUrl: (json['site_url'] as String?) ?? '',
      siteType: json['site_type'] as String?,
      exchangeRate: (json['exchange_rate'] as num?)?.toDouble(),
      accountInfo: rawInfo is Map
          ? PluginAccountInfo.fromJson(Map<String, dynamic>.from(rawInfo))
          : null,
      createdAt: (json['created_at'] as num?)?.toInt(),
      updatedAt: (json['updated_at'] as num?)?.toInt(),
      notes: json['notes'] as String?,
      tagIds: rawTagIds is List
          ? rawTagIds.whereType<String>().toList(growable: false)
          : const [],
      disabled: json['disabled'] as bool?,
      excludeFromTotalBalance: json['excludeFromTotalBalance'] as bool?,
      authType: json['authType'] as String?,
      sessionCookie: rawCookieAuth is Map
          ? rawCookieAuth['sessionCookie'] as String?
          : null,
      checkIn: rawCheckIn is Map
          ? PluginCheckIn.fromJson(Map<String, dynamic>.from(rawCheckIn))
          : null,
      manualBalanceUsd: json['manualBalanceUsd'] as String?,
    );
  }
}

/// The `account_info` block of a plugin site account.
class PluginAccountInfo {
  /// Upstream-stable account id (`id`). Stored as a string by the plugin but
  /// occasionally numeric; always normalized to a string here.
  final String? id;

  /// Bearer access token (`access_token`).
  final String? accessToken;

  /// Upstream username (`username`).
  final String? username;

  /// Remaining quota in token units (`quota`). Already the *remaining* balance
  /// — never subtract `used_quota` from it.
  final num? quota;

  const PluginAccountInfo({
    required this.id,
    required this.accessToken,
    required this.username,
    required this.quota,
  });

  factory PluginAccountInfo.fromJson(Map<String, dynamic> json) {
    return PluginAccountInfo(
      id: json['id']?.toString(),
      accessToken: json['access_token'] as String?,
      username: json['username'] as String?,
      quota: json['quota'] as num?,
    );
  }
}

/// The `checkIn` block of a plugin site account.
///
/// Only the fields this project persists are kept: the auto check-in toggle and
/// the nested `customCheckIn.url` / `customCheckIn.redeemUrl`. Detection flags,
/// turnstile config and site status are intentionally dropped.
class PluginCheckIn {
  /// Whether automatic check-in is enabled (`autoCheckInEnabled`).
  final bool? autoCheckInEnabled;

  /// Custom check-in URL (`customCheckIn.url`). Empty string means "unset".
  final String? customCheckInUrl;

  /// Custom redemption URL (`customCheckIn.redeemUrl`). Empty means "unset".
  final String? redeemUrl;

  const PluginCheckIn({
    required this.autoCheckInEnabled,
    required this.customCheckInUrl,
    required this.redeemUrl,
  });

  factory PluginCheckIn.fromJson(Map<String, dynamic> json) {
    final rawCustom = json['customCheckIn'];
    String? url;
    String? redeemUrl;
    if (rawCustom is Map) {
      url = rawCustom['url'] as String?;
      redeemUrl = rawCustom['redeemUrl'] as String?;
    }
    return PluginCheckIn(
      autoCheckInEnabled: json['autoCheckInEnabled'] as bool?,
      customCheckInUrl: url,
      redeemUrl: redeemUrl,
    );
  }
}

/// A single entry from the plugin's global tag store (`tagStore.tagsById`).
class PluginTag {
  /// Plugin tag id (e.g. `tag-...`). Reused as-is when the tag is new locally.
  final String id;

  /// Display name (case preserved).
  final String name;

  /// Creation timestamp in epoch milliseconds.
  final int? createdAt;

  /// Last-update timestamp in epoch milliseconds.
  final int? updatedAt;

  const PluginTag({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PluginTag.fromJson(Map<String, dynamic> json) {
    return PluginTag(
      id: (json['id'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      createdAt: (json['createdAt'] as num?)?.toInt(),
      updatedAt: (json['updatedAt'] as num?)?.toInt(),
    );
  }
}
