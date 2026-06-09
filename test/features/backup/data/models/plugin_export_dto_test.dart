import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:fl_api_hub/features/backup/data/models/plugin_export_dto.dart';

void main() {
  group('PluginExport.fromJson', () {
    group('with the bundled template', () {
      late PluginExport export;

      setUpAll(() {
        // flutter test runs from the package root.
        final file = File(
          'docs/API 文档/all-api-hub-export-accounts-template.json',
        );
        final json =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        export = PluginExport.fromJson(json);
      });

      test('parses envelope metadata', () {
        expect(export.version, '2.0');
        expect(export.type, 'accounts');
        expect(export.timestamp, 1781008077911);
      });

      test('parses both accounts and the ordering hint', () {
        expect(export.accounts, hasLength(2));
        expect(export.orderedAccountIds, hasLength(2));
        expect(
          export.orderedAccountIds.first,
          'account_1765503130831_a46ux20eh',
        );
      });

      test('flattens the 7-entry tag store', () {
        expect(export.tagStore, hasLength(7));
        expect(
          export.tagStore.map((t) => t.name),
          containsAll(<String>['关站归档', '翻译', 'Coding', '可酒馆']),
        );
      });

      test('parses the cookie (Anyrouter) account', () {
        final anyrouter = export.accounts.firstWhere(
          (a) => a.siteName == 'Anyrouter',
        );
        expect(anyrouter.siteUrl, 'https://anyrouter.top');
        expect(anyrouter.siteType, 'anyrouter');
        expect(anyrouter.authType, 'cookie');
        // Session cookie is kept verbatim (prefix stripping happens later in
        // the account mapper, not in the DTO).
        expect(anyrouter.sessionCookie, 'session=xxxxxxx');
        expect(anyrouter.disabled, isFalse);
        expect(anyrouter.manualBalanceUsd, '');
        expect(anyrouter.tagIds, ['tag-608136db-1992-4bf3-9ee4-58c7e2612ee4']);
        expect(anyrouter.checkIn?.autoCheckInEnabled, isFalse);

        final info = anyrouter.accountInfo!;
        expect(info.id, '77742');
        expect(info.username, 'linuxdo_77742');
        expect(info.quota, 2074349914);
      });

      test('parses the access-token (Neb) account', () {
        final neb = export.accounts.firstWhere((a) => a.siteName == 'Neb 公益站');
        expect(neb.siteType, 'new-api');
        expect(neb.authType, 'access_token');
        expect(neb.sessionCookie, isNull);
        expect(neb.accountInfo!.accessToken, 'xxxxxxx');
        expect(neb.checkIn?.autoCheckInEnabled, isTrue);
      });
    });

    group('validation', () {
      test('throws when type is not "accounts"', () {
        expect(
          () => PluginExport.fromJson({
            'version': '2.0',
            'type': 'bookmarks',
            'accounts': {'accounts': <dynamic>[]},
          }),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws when the type key is missing entirely', () {
        expect(
          () => PluginExport.fromJson({'version': '2.0'}),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws when the accounts object is missing', () {
        expect(
          () => PluginExport.fromJson({'version': '2.0', 'type': 'accounts'}),
          throwsA(isA<FormatException>()),
        );
      });

      test('throws when the nested accounts array is missing', () {
        expect(
          () => PluginExport.fromJson({
            'version': '2.0',
            'type': 'accounts',
            'accounts': <String, dynamic>{},
          }),
          throwsA(isA<FormatException>()),
        );
      });

      test('accepts an empty accounts array as valid (zero accounts)', () {
        final export = PluginExport.fromJson({
          'version': '2.0',
          'type': 'accounts',
          'accounts': {'accounts': <dynamic>[]},
        });
        expect(export.accounts, isEmpty);
        expect(export.tagStore, isEmpty);
        expect(export.orderedAccountIds, isEmpty);
      });
    });
  });
}
