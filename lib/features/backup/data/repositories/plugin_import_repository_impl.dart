/// Coordinates importing browser-plugin export data into local storage.
///
/// Reads the export file and snapshots the local store on the main isolate
/// (Hive is not reachable from a background isolate), then performs the
/// CPU-bound parse + map + merge inside [Isolate.run], and finally appends the
/// merged result back into Hive. The write is the last step, so any parse
/// failure aborts with zero writes.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import '../../../../core/error/app_exception.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/plugin_import_summary.dart';
import '../../domain/repositories/plugin_import_repository.dart';
import '../datasources/backup_file_datasource.dart';
import '../datasources/backup_hive_reader.dart';
import '../models/plugin_export_dto.dart';
import '../models/plugin_import_merger.dart';

class PluginImportRepositoryImpl implements PluginImportRepository {
  final BackupHiveReader _hiveReader;
  final BackupFileDataSource _fileDataSource;

  PluginImportRepositoryImpl(this._hiveReader, this._fileDataSource);

  @override
  Future<Result<PluginImportSummary>> importFromFile(String filePath) async {
    try {
      // Main isolate: read the file bytes and snapshot the local store. These
      // become plain, sendable inputs to the background isolate — Hive itself
      // is never touched off the main isolate.
      final bytes = await _fileDataSource.readFile(filePath);
      final local = _hiveReader.readAll();
      final localAccounts = local.accounts;
      final localTags = local.tags;

      // Background isolate: parse + map + merge. The closure captures only the
      // bytes and the two raw map lists; it never references a Ref or Hive box.
      final PluginMergeResult merged;
      try {
        merged = await Isolate.run(() {
          final decoded = jsonDecode(utf8.decode(bytes));
          if (decoded is! Map) {
            throw const FormatException('不是有效的 All-API-Hub 导出文件');
          }
          final export = PluginExport.fromJson(
            Map<String, dynamic>.from(decoded),
          );
          return PluginImportMerger.merge(
            export,
            localAccounts: localAccounts,
            localTags: localTags,
          );
        });
      } on FormatException {
        // Not a valid plugin file (bad JSON, wrong `type`, missing accounts).
        // Abort before any write so local data is left untouched.
        return const Failure(
          BackupException(message: '不是有效的 All-API-Hub 导出文件'),
        );
      }

      // Main isolate: append-only write (put by id). New accounts carry fresh
      // UUIDs, so they can never collide with existing local records.
      await _hiveReader.writeData(merged.resolved);

      return Success(merged.summary);
    } catch (e, st) {
      return Failure(
        BackupException(message: '导入失败：$e', originalError: e, stackTrace: st),
      );
    }
  }
}
