import 'package:flutter_test/flutter_test.dart';

import 'package:fl_api_hub/features/backup/data/models/plugin_export_dto.dart';
import 'package:fl_api_hub/features/backup/data/models/plugin_import_merger.dart';
import 'package:fl_api_hub/features/backup/domain/entities/plugin_import_summary.dart';

void main() {
  group('PluginImportMerger.merge', () {
    // Fresh, deterministic id generator per test.
    String Function() makeGen() {
      var i = 0;
      return () => 'gen-${i++}';
    }

    PluginSiteAccount account({
      required String id,
      String siteUrl = 'https://example.com',
      String username = 'user',
      List<String> tagIds = const [],
    }) {
      return PluginSiteAccount(
        id: id,
        siteName: 'Site $id',
        siteUrl: siteUrl,
        siteType: 'new-api',
        exchangeRate: 7.3,
        accountInfo: PluginAccountInfo(
          id: '1',
          accessToken: 'token',
          username: username,
          quota: 1000000,
        ),
        createdAt: 1765503130830,
        updatedAt: 1780591410616,
        notes: '',
        tagIds: tagIds,
        disabled: false,
        excludeFromTotalBalance: false,
        authType: 'access_token',
        sessionCookie: null,
        checkIn: null,
        manualBalanceUsd: '',
      );
    }

    PluginTag tag(String id, String name) {
      return PluginTag(
        id: id,
        name: name,
        createdAt: 1769240178614,
        updatedAt: 1769240178614,
      );
    }

    PluginExport export({
      required List<PluginSiteAccount> accounts,
      List<PluginTag> tags = const [],
      List<String>? orderedIds,
    }) {
      return PluginExport(
        version: '2.0',
        timestamp: 1781008077911,
        type: 'accounts',
        accounts: accounts,
        orderedAccountIds:
            orderedIds ?? accounts.map((a) => a.id).toList(growable: false),
        tagStore: tags,
      );
    }

    Map<String, dynamic> localAccount({
      required String baseUrl,
      required String username,
      int sortOrder = 0,
    }) {
      return {
        'id': 'local-$username',
        'baseUrl': baseUrl,
        'username': username,
        'sortOrder': sortOrder,
      };
    }

    test('imports everything into an empty local store', () {
      final result = PluginImportMerger.merge(
        export(
          accounts: [
            account(
              id: 'a1',
              siteUrl: 'https://s1.com',
              username: 'u1',
              tagIds: const ['t-coding'],
            ),
            account(id: 'a2', siteUrl: 'https://s2.com', username: 'u2'),
          ],
          tags: [tag('t-coding', 'Coding'), tag('t-chat', 'Chat')],
        ),
        localAccounts: const [],
        localTags: const [],
        generateId: makeGen(),
      );

      expect(
        result.summary,
        const PluginImportSummary(accountsImported: 2, tagsImported: 2),
      );
      expect(result.resolved.accounts, hasLength(2));
      expect(result.resolved.tags, hasLength(2));
      expect(result.resolved.keys, isEmpty);
      expect(result.resolved.checkInTasks, isEmpty);

      // New tags keep their plugin id, so the account tag reference is intact.
      final a1 = result.resolved.accounts.firstWhere(
        (m) => m['baseUrl'] == 'https://s1.com',
      );
      expect(a1['tagIds'], ['t-coding']);
      expect(a1['id'], startsWith('gen-'));

      final coding = result.resolved.tags.firstWhere(
        (t) => t['id'] == 't-coding',
      );
      expect(coding['name'], 'Coding');
      expect(coding['createdAt'], isA<String>());
    });

    test('reuses an existing local tag by case-insensitive name', () {
      final result = PluginImportMerger.merge(
        export(
          accounts: [
            account(id: 'a1', tagIds: const ['plugin-coding']),
          ],
          tags: [tag('plugin-coding', 'coding')],
        ),
        localAccounts: const [],
        localTags: const [
          {'id': 'local-coding', 'name': 'Coding'},
        ],
        generateId: makeGen(),
      );

      expect(result.summary.tagsReused, 1);
      expect(result.summary.tagsImported, 0);
      // No new tag is written — the local one is reused.
      expect(result.resolved.tags, isEmpty);
      // The account's tag id is remapped to the local tag id.
      expect(result.resolved.accounts.single['tagIds'], ['local-coding']);
    });

    test('skips an account that matches a local baseUrl + username', () {
      final result = PluginImportMerger.merge(
        export(
          accounts: [
            account(id: 'a1', siteUrl: 'https://dup.com', username: 'dupuser'),
          ],
        ),
        localAccounts: [
          localAccount(baseUrl: 'https://dup.com', username: 'dupuser'),
        ],
        localTags: const [],
        generateId: makeGen(),
      );

      expect(result.summary.accountsSkipped, 1);
      expect(result.summary.accountsImported, 0);
      expect(result.resolved.accounts, isEmpty);
    });

    test('appends sortOrder after the largest local sortOrder', () {
      final result = PluginImportMerger.merge(
        export(
          accounts: [
            account(id: 'a1', siteUrl: 'https://new1.com', username: 'n1'),
            account(id: 'a2', siteUrl: 'https://new2.com', username: 'n2'),
          ],
          orderedIds: const ['a1', 'a2'],
        ),
        localAccounts: [
          localAccount(baseUrl: 'https://x.com', username: 'x', sortOrder: 7),
        ],
        localTags: const [],
        generateId: makeGen(),
      );

      // baseSortOrder = 7 → 7 + 1 + orderIndex.
      expect(result.resolved.accounts.map((m) => m['sortOrder']).toList(), [
        8,
        9,
      ]);
    });

    test('honors orderedAccountIds, appending unlisted accounts last', () {
      final result = PluginImportMerger.merge(
        export(
          accounts: [
            account(id: 'a1', siteUrl: 'https://1.com', username: 'u1'),
            account(id: 'a2', siteUrl: 'https://2.com', username: 'u2'),
            account(id: 'a3', siteUrl: 'https://3.com', username: 'u3'),
          ],
          orderedIds: const ['a3', 'a1'], // a2 deliberately omitted
        ),
        localAccounts: const [],
        localTags: const [],
        generateId: makeGen(),
      );

      expect(result.resolved.accounts.map((m) => m['baseUrl']).toList(), [
        'https://3.com',
        'https://1.com',
        'https://2.com',
      ]);
    });

    test('advances orderIndex for skipped accounts (gap in sortOrder)', () {
      final result = PluginImportMerger.merge(
        export(
          accounts: [
            account(id: 'a1', siteUrl: 'https://dup.com', username: 'dup'),
            account(id: 'a2', siteUrl: 'https://new.com', username: 'new'),
          ],
          orderedIds: const ['a1', 'a2'],
        ),
        localAccounts: [
          localAccount(baseUrl: 'https://dup.com', username: 'dup'),
        ],
        localTags: const [],
        generateId: makeGen(),
      );

      // a1 (orderIndex 0) skipped; a2 imported at orderIndex 1 → 0 + 1 + 1.
      expect(result.summary.accountsImported, 1);
      expect(result.summary.accountsSkipped, 1);
      expect(result.resolved.accounts.single['sortOrder'], 2);
    });

    test('collapses duplicate plugin tag names onto a single new tag', () {
      final result = PluginImportMerger.merge(
        export(
          accounts: [
            account(id: 'a1', tagIds: const ['dup-1', 'dup-2']),
          ],
          tags: [tag('dup-1', 'Work'), tag('dup-2', 'work')],
        ),
        localAccounts: const [],
        localTags: const [],
        generateId: makeGen(),
      );

      // Both plugin tags share a normalized name → only one new tag.
      expect(result.summary.tagsImported, 1);
      expect(result.summary.tagsReused, 1);
      expect(result.resolved.tags, hasLength(1));
      // Both references collapse onto the first (kept) tag id and dedupe.
      expect(result.resolved.accounts.single['tagIds'], ['dup-1']);
    });
  });
}
