# Implement — 导入 All-API-Hub 插件导出数据

## 批次划分（顺序执行；每批完成后单独 `flutter analyze` + 对应测试）

### 批次 1 · DTO 解析层
- [ ] 新增 `lib/features/backup/data/models/plugin_export_dto.dart`：`PluginExport`/`PluginSiteAccount`/`PluginAccountInfo`/`PluginCheckIn`/`PluginTag`，`fromJson` + 顶层 `type=="accounts"` 校验（非法抛 `FormatException`）。
- [ ] 新增 `test/features/backup/plugin_export_dto_test.dart`：用 `docs/API 文档/all-api-hub-export-accounts-template.json` 验证解析；喂非法/缺字段断言抛错。
- 验证：`flutter analyze` + 该测试。

### 批次 2 · 账号映射器
- [ ] 新增 `lib/features/backup/data/models/plugin_account_mapper.dart`：`toMap(PluginSiteAccount, orderIndex, baseSortOrder, tagIdRemap)`。
- [ ] 覆盖转换分支：cookie 剥 `session=` 前缀 / `access_token` 取值、`disabled` 取反、`quota/500000` 余额、`manualBalanceUsd` 空串→null、`site_type` 未知→`unknown`、`userId` string→int、ms→ISO8601、`checkIn` 嵌套展平、`redeemUrl`→`redemptionUrl`。
- [ ] 新增 `test/features/backup/plugin_account_mapper_test.dart`。
- 验证：`flutter analyze` + 该测试。

### 批次 3 · 去重合并器 + 结果实体
- [ ] 新增 `lib/features/backup/domain/entities/plugin_import_summary.dart`。
- [ ] 新增 `lib/features/backup/data/models/plugin_import_merger.dart`：标签 by `name`(lower) 重映射 → 账号 by `baseUrl+username` 跳过 → `sortOrder` 追加（算法见 design §4）。
- [ ] 新增 `test/features/backup/plugin_import_merger_test.dart`：空本地全新增、同名标签复用、重复账号跳过、`tagIds` 重映射正确、`sortOrder` 接在本地最大值之后。
- 验证：`flutter analyze` + 该测试。

### 批次 4 · Repository + Provider + 状态机
- [ ] 新增 `domain/repositories/plugin_import_repository.dart`（接口）。
- [ ] 新增 `data/repositories/plugin_import_repository_impl.dart`：读字节 → `Isolate.run`(解析+映射+合并) → `BackupHiveReader.writeData` → `Result<PluginImportSummary>`。**注意**：`local` 账号/标签需在 isolate 外用 `readAll()` 读出后作为参数传入（isolate 内不可访问 Hive，对齐现有 `createBackup` 模式）。
- [ ] 新增 `presentation/providers/plugin_import_{state,notifier,providers}.dart`。
- 验证：`flutter analyze`。

### 批次 5 · UI 集成
- [ ] 改 `lib/features/backup/presentation/pages/backup_page.dart`：新增独立 `SectionCard`「从浏览器插件导入」+ `_onImportPlugin()`（pickFile → notifier → 进度 → 结果页 → reset）。
- [ ] 新增 `presentation/pages/plugin_import_result_page.dart`（仿 `restore_result_page.dart`）。
- [ ] widget 测试：入口可见、点击触发文件选择（mock）。
- 验证：`dart format .` + `flutter analyze` + `flutter test`（全量）。

## 验证命令

```bash
dart format .
flutter analyze                                    # 必须 0 warning
flutter test test/features/backup/                 # 分批跑对应文件
flutter test                                       # 批次 5 后全量回归
```

手动验证：设置 → 数据管理 → 从浏览器插件导入 → 选 `docs/API 文档/all-api-hub-export-accounts-template.json` → 核对 2 账号落库、`Coding` 标签复用/新增、Anyrouter 为 cookie 认证、余额≈4148.70；再导入一次应全部跳过。

## 风险文件 / 回滚点

- 唯一改动的现存文件是 `backup_page.dart`；其余均为新增文件，可单文件 `git checkout --` 回滚。
- 纯追加写入（新账号用全新 UUID，绝不撞本地 key）、无 schema 迁移、无加密 —— 异常时本地数据保持不变即为天然回滚。
- `Isolate.run` 闭包内禁止捕获 `Ref`/Hive box；所有本地数据必须先在外层读出再传参。

## 完成前检查

- [ ] `prd.md` 验收标准逐条满足（含幂等性、不破坏本地）。
- [ ] `flutter analyze` 0 warning、`flutter test` 全绿、`dart format .` 已执行。
- [ ] 余额换算与 `.trellis/spec/backend/api-quota-balance-contract.md` 一致（无双重扣减）。
