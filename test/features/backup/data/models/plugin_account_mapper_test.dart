import 'package:flutter_test/flutter_test.dart';

import 'package:fl_api_hub/core/config/app_defaults.dart';
import 'package:fl_api_hub/core/network/site_type.dart';
import 'package:fl_api_hub/features/accounts/data/models/account_mapper.dart';
import 'package:fl_api_hub/features/backup/data/models/plugin_account_mapper.dart';
import 'package:fl_api_hub/features/backup/data/models/plugin_export_dto.dart';

void main() {
  group('PluginAccountMapper.toMap', () {
    PluginSiteAccount buildAccount({
      String id = 'account_1',
      String siteName = 'Test Site',
      String siteUrl = 'https://example.com',
      String? siteType = 'new-api',
      double? exchangeRate = 7.3,
      PluginAccountInfo? accountInfo,
      int? createdAt = 1765503130830,
      int? updatedAt = 1780591410616,
      String? notes = 'note',
      List<String> tagIds = const [],
      bool? disabled = false,
      bool? excludeFromTotalBalance = false,
      String? authType = 'access_token',
      String? sessionCookie,
      PluginCheckIn? checkIn,
      String? manualBalanceUsd = '',
    }) {
      return PluginSiteAccount(
        id: id,
        siteName: siteName,
        siteUrl: siteUrl,
        siteType: siteType,
        exchangeRate: exchangeRate,
        accountInfo:
            accountInfo ??
            const PluginAccountInfo(
              id: '77742',
              accessToken: 'sk-access-token',
              username: 'linuxdo_77742',
              quota: 2074349914,
            ),
        createdAt: createdAt,
        updatedAt: updatedAt,
        notes: notes,
        tagIds: tagIds,
        disabled: disabled,
        excludeFromTotalBalance: excludeFromTotalBalance,
        authType: authType,
        sessionCookie: sessionCookie,
        checkIn: checkIn,
        manualBalanceUsd: manualBalanceUsd,
      );
    }

    Map<String, dynamic> mapOf(
      PluginSiteAccount acc, {
      int orderIndex = 0,
      int baseSortOrder = 0,
      Map<String, String> tagIdRemap = const {},
      String newId = 'new-uuid',
    }) {
      return PluginAccountMapper.toMap(
        acc,
        orderIndex: orderIndex,
        baseSortOrder: baseSortOrder,
        tagIdRemap: tagIdRemap,
        newId: newId,
      );
    }

    test('uses the caller-supplied id, name and base url', () {
      final map = mapOf(buildAccount(), newId: 'fixed-id');
      expect(map['id'], 'fixed-id');
      expect(map['name'], 'Test Site');
      expect(map['baseUrl'], 'https://example.com');
    });

    test('maps an access-token account', () {
      final map = mapOf(
        buildAccount(
          authType: 'access_token',
          accountInfo: const PluginAccountInfo(
            id: '77742',
            accessToken: 'sk-the-token',
            username: 'admin',
            quota: 0,
          ),
        ),
      );
      expect(map['authType'], 'accessToken');
      expect(map['accessToken'], 'sk-the-token');
      expect(map['username'], 'admin');
    });

    test('strips the session= prefix for cookie accounts', () {
      final map = mapOf(
        buildAccount(authType: 'cookie', sessionCookie: 'session=abc123'),
      );
      expect(map['authType'], 'cookie');
      expect(map['accessToken'], 'abc123');
    });

    test('keeps the cookie verbatim when there is no session= prefix', () {
      final map = mapOf(
        buildAccount(authType: 'cookie', sessionCookie: 'raw-cookie-value'),
      );
      expect(map['accessToken'], 'raw-cookie-value');
    });

    test('inverts disabled into enabled', () {
      expect(mapOf(buildAccount(disabled: false))['enabled'], isTrue);
      expect(mapOf(buildAccount(disabled: true))['enabled'], isFalse);
      // Missing disabled flag defaults to enabled.
      expect(mapOf(buildAccount(disabled: null))['enabled'], isTrue);
    });

    test('converts quota to a USD balance without deducting usage', () {
      final map = mapOf(
        buildAccount(
          accountInfo: const PluginAccountInfo(
            id: '1',
            accessToken: 't',
            username: 'u',
            quota: 2074349914,
          ),
        ),
      );
      // 2074349914 / 500000 == 4148.699828 (≈ 4148.70), with no usage subtracted.
      expect(map['balance'] as double, closeTo(4148.70, 0.01));
      expect(map['balance'], 2074349914 / kDefaultQuotaPerUnit);
    });

    test('balance is null when quota is unavailable', () {
      // accountInfo omitted entirely (some plugin exports lack the block);
      // built directly because the helper substitutes a default for null.
      const acc = PluginSiteAccount(
        id: 'account_1',
        siteName: 'Test Site',
        siteUrl: 'https://example.com',
        siteType: 'new-api',
        exchangeRate: 7.3,
        accountInfo: null,
        createdAt: 1765503130830,
        updatedAt: 1780591410616,
        notes: 'note',
        tagIds: [],
        disabled: false,
        excludeFromTotalBalance: false,
        authType: 'access_token',
        sessionCookie: null,
        checkIn: null,
        manualBalanceUsd: '',
      );
      final map = mapOf(acc);
      expect(map['balance'], isNull);
      // Missing account info also yields the username / userId sentinels.
      expect(map['username'], '');
      expect(map['userId'], -1);
    });

    test('parses manualBalanceUsd: empty -> null, value -> double', () {
      expect(
        mapOf(buildAccount(manualBalanceUsd: ''))['manualBalanceUsd'],
        isNull,
      );
      expect(
        mapOf(buildAccount(manualBalanceUsd: null))['manualBalanceUsd'],
        isNull,
      );
      expect(
        mapOf(buildAccount(manualBalanceUsd: '50.00'))['manualBalanceUsd'],
        50.0,
      );
    });

    test('falls back to SiteType.unknown for unrecognized site types', () {
      expect(
        mapOf(buildAccount(siteType: 'anyrouter'))['siteType'],
        'anyrouter',
      );
      expect(
        mapOf(buildAccount(siteType: 'totally-unknown'))['siteType'],
        SiteType.unknown.value,
      );
      expect(
        mapOf(buildAccount(siteType: null))['siteType'],
        SiteType.unknown.value,
      );
    });

    test('parses userId from a string, sentinel -1 when unparseable', () {
      expect(
        mapOf(
          buildAccount(
            accountInfo: const PluginAccountInfo(
              id: '77742',
              accessToken: 't',
              username: 'u',
              quota: 0,
            ),
          ),
        )['userId'],
        77742,
      );
      expect(
        mapOf(
          buildAccount(
            accountInfo: const PluginAccountInfo(
              id: 'user-001',
              accessToken: 't',
              username: 'u',
              quota: 0,
            ),
          ),
        )['userId'],
        -1,
      );
    });

    test('converts millisecond timestamps to ISO-8601', () {
      final map = mapOf(
        buildAccount(createdAt: 1765503130830, updatedAt: 1780591410616),
      );
      expect(
        map['createdAt'],
        DateTime.fromMillisecondsSinceEpoch(1765503130830).toIso8601String(),
      );
      expect(
        map['updatedAt'],
        DateTime.fromMillisecondsSinceEpoch(1780591410616).toIso8601String(),
      );
    });

    test('flattens the nested check-in block', () {
      final map = mapOf(
        buildAccount(
          checkIn: const PluginCheckIn(
            autoCheckInEnabled: true,
            customCheckInUrl: 'https://welfare.example.com/checkin',
            redeemUrl: 'https://welfare.example.com/redeem',
          ),
        ),
      );
      final checkIn = map['checkIn'] as Map;
      expect(checkIn['autoCheckInEnabled'], isTrue);
      expect(
        checkIn['customCheckInUrl'],
        'https://welfare.example.com/checkin',
      );
      expect(map['redemptionUrl'], 'https://welfare.example.com/redeem');
    });

    test('treats empty custom URLs as null', () {
      final map = mapOf(
        buildAccount(
          checkIn: const PluginCheckIn(
            autoCheckInEnabled: false,
            customCheckInUrl: '',
            redeemUrl: '',
          ),
        ),
      );
      final checkIn = map['checkIn'] as Map;
      expect(checkIn['autoCheckInEnabled'], isFalse);
      expect(checkIn['customCheckInUrl'], isNull);
      expect(map['redemptionUrl'], isNull);
    });

    test('defaults check-in to disabled when the block is absent', () {
      final map = mapOf(buildAccount(checkIn: null));
      final checkIn = map['checkIn'] as Map;
      expect(checkIn['autoCheckInEnabled'], isFalse);
      expect(checkIn['customCheckInUrl'], isNull);
      expect(map['redemptionUrl'], isNull);
    });

    test('appends sortOrder after the base, by order index', () {
      expect(
        mapOf(buildAccount(), orderIndex: 0, baseSortOrder: 5)['sortOrder'],
        6,
      );
      expect(
        mapOf(buildAccount(), orderIndex: 3, baseSortOrder: 5)['sortOrder'],
        9,
      );
    });

    test('remaps tag ids and drops unknown ones', () {
      final map = mapOf(
        buildAccount(tagIds: const ['plugin-a', 'plugin-missing']),
        tagIdRemap: const {'plugin-a': 'local-1'},
      );
      expect(map['tagIds'], ['local-1']);
    });

    test('always follows the global proxy with no per-account config', () {
      final map = mapOf(buildAccount());
      expect(map['proxyMode'], 'followGlobal');
      expect(map['proxyConfig'], isNull);
      expect(map['exchangeRate'], 7.3);
      expect(map['excludeFromTotalBalance'], isFalse);
      expect(map['notes'], 'note');
    });

    test('produces a map AccountMapper.fromMap can rehydrate (round-trip)', () {
      final map = mapOf(
        buildAccount(
          siteName: 'Anyrouter',
          siteUrl: 'https://anyrouter.top',
          siteType: 'anyrouter',
          authType: 'cookie',
          sessionCookie: 'session=cookie-value',
          tagIds: const ['plugin-a'],
          checkIn: const PluginCheckIn(
            autoCheckInEnabled: true,
            customCheckInUrl: 'https://anyrouter.top/checkin',
            redeemUrl: 'https://anyrouter.top/redeem',
          ),
          accountInfo: const PluginAccountInfo(
            id: '77742',
            accessToken: 'ignored-for-cookie',
            username: 'linuxdo_77742',
            quota: 2074349914,
          ),
        ),
        orderIndex: 1,
        baseSortOrder: 10,
        tagIdRemap: const {'plugin-a': 'local-1'},
        newId: 'generated-uuid',
      );

      final account = AccountMapper.fromMap(map);

      expect(account.id, 'generated-uuid');
      expect(account.name, 'Anyrouter');
      expect(account.baseUrl, 'https://anyrouter.top');
      expect(account.siteType, SiteType.anyrouter);
      expect(account.authType, AuthType.cookie);
      expect(account.accessToken, 'cookie-value');
      expect(account.username, 'linuxdo_77742');
      expect(account.userId, 77742);
      expect(account.balance, closeTo(4148.70, 0.01));
      expect(account.tagIds, ['local-1']);
      expect(account.checkIn.autoCheckInEnabled, isTrue);
      expect(account.checkIn.customCheckInUrl, 'https://anyrouter.top/checkin');
      expect(account.redemptionUrl, 'https://anyrouter.top/redeem');
      expect(account.sortOrder, 12);
      expect(account.enabled, isTrue);
    });
  });
}
