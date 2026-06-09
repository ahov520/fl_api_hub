/// Widget tests for the "从浏览器插件导入" entry on [BackupPage].
///
/// Covers:
/// - The plugin-import entry is visible.
/// - Tapping it triggers file selection.
/// - A successful import navigates to [PluginImportResultPage] with the summary.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'package:fl_api_hub/core/result/result.dart';
import 'package:fl_api_hub/features/backup/data/datasources/backup_file_datasource.dart';
import 'package:fl_api_hub/features/backup/domain/entities/plugin_import_summary.dart';
import 'package:fl_api_hub/features/backup/domain/repositories/plugin_import_repository.dart';
import 'package:fl_api_hub/features/backup/presentation/pages/backup_page.dart';
import 'package:fl_api_hub/features/backup/presentation/pages/plugin_import_result_page.dart';
import 'package:fl_api_hub/features/backup/presentation/providers/backup_providers.dart';
import 'package:fl_api_hub/features/backup/presentation/providers/plugin_import_providers.dart';

/// File source whose [pickFile] returns a fixed path and records invocations.
class _FakeFileDataSource extends BackupFileDataSource {
  _FakeFileDataSource(this._path);

  final String? _path;
  int pickFileCalls = 0;

  @override
  Future<String?> pickFile() async {
    pickFileCalls++;
    return _path;
  }
}

/// Import repository returning a fixed result and recording the path.
class _FakeImportRepository implements PluginImportRepository {
  _FakeImportRepository(this._result);

  final Result<PluginImportSummary> _result;
  int importCalls = 0;
  String? lastPath;

  @override
  Future<Result<PluginImportSummary>> importFromFile(String filePath) async {
    importCalls++;
    lastPath = filePath;
    return _result;
  }
}

void main() {
  late Directory tempDir;

  setUp(() async {
    // BackupPage reads the Hive-backed backupPasswordStoreProvider
    // (Hive.box('app_data')). The accounts/tags boxes back the providers a
    // successful import invalidates, so open all three.
    tempDir = await Directory.systemTemp.createTemp('hive_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('app_data');
    await Hive.openBox('accounts');
    await Hive.openBox('tags');
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> pump(
    WidgetTester tester, {
    required BackupFileDataSource fileDataSource,
    PluginImportRepository? importRepository,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backupFileDataSourceProvider.overrideWithValue(fileDataSource),
          if (importRepository != null)
            pluginImportRepositoryProvider.overrideWithValue(importRepository),
        ],
        child: const MaterialApp(home: BackupPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the plugin-import entry', (tester) async {
    await pump(tester, fileDataSource: _FakeFileDataSource(null));

    expect(find.text('导入 All-API-Hub 插件数据'), findsOneWidget);
  });

  testWidgets('tapping the entry triggers file selection', (tester) async {
    final fileSource = _FakeFileDataSource(null); // user cancels the picker
    await pump(tester, fileDataSource: fileSource);

    await tester.tap(find.text('导入 All-API-Hub 插件数据'));
    await tester.pumpAndSettle();

    expect(fileSource.pickFileCalls, 1);
  });

  testWidgets('successful import navigates to the result page', (tester) async {
    final fileSource = _FakeFileDataSource('/tmp/plugin.json');
    final repo = _FakeImportRepository(
      const Success(
        PluginImportSummary(
          accountsImported: 2,
          accountsSkipped: 1,
          tagsImported: 1,
          tagsReused: 1,
        ),
      ),
    );
    await pump(tester, fileDataSource: fileSource, importRepository: repo);

    await tester.tap(find.text('导入 All-API-Hub 插件数据'));
    await tester.pumpAndSettle();

    expect(repo.importCalls, 1);
    expect(repo.lastPath, '/tmp/plugin.json');
    expect(find.byType(PluginImportResultPage), findsOneWidget);
    expect(find.text('导入完成'), findsOneWidget);
  });
}
