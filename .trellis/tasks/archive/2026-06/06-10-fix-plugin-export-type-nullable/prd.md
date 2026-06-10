# 修复 PluginExport 解析完整导出数据时 type 校验误拒

## 目标与用户价值

All-API-Hub 浏览器插件支持两种导出：「仅账号数据」（顶层含 `type: "accounts"`）和「完整数据」（顶层**没有** `type` 字段）。当前 `PluginExport.fromJson` 强制校验 `json['type'] == 'accounts'`，导致用户选择"完整数据"导出的文件被误判为"不是有效的 All-API-Hub 导出文件"，无法导入。

修复后两种导出文件都能正常导入账号数据。

## 已确认事实（代码库证据）

- `lib/features/backup/data/models/plugin_export_dto.dart:53` — `if (json['type'] != 'accounts') throw FormatException(...)` 是误拒来源；:52 已留 TODO
- `type` 属性为 `final String type`（:24），构造与 `fromJson`（:96 `json['type'] as String`）均按非空处理
- 结构校验链（`accounts` 必须是 Map、`accounts.accounts` 必须是 List，:57-64）独立于 type 校验，保留后仍能拒绝非法文件，维持"单一校验闸门、零写入中止"语义
- 测试现状 `test/features/backup/data/models/plugin_export_dto_test.dart`：
  - :25 `expect(export.type, 'accounts')` — 保留（仅账号导出仍带 type）
  - :78 `throws when type is not "accounts"` — 与新行为冲突，需删除或改写
  - :89 `throws when the type key is missing entirely` — 与新行为直接冲突（该用例 payload 也缺 `accounts`，结构校验仍会抛，需改写语义）
- `docs/API 文档/export-json-data.md` 仅描述「仅账号数据」格式；完整导出格式无文档，但用户实测确认其顶层无 `type` 且账号数据结构兼容
- 调用方 `plugin_import_repository_impl.dart` 只依赖 `FormatException` 作为"非插件文件"信号，不读取 `type` 字段，无连锁改动

## 需求

1. `PluginExport.type` 改为 `String?`，`fromJson` 中按 `json['type'] as String?` 读取
2. `fromJson` 移除 `type != 'accounts'` 的拒绝逻辑（同时删除 :52 的 TODO 注释），文件有效性完全由 `accounts.accounts` 结构校验决定
3. 更新 `type` 字段与 `fromJson` 的 doc comment：不再声称 "must equal accounts"，说明完整数据导出无 type
4. 更新单元测试：
   - 删除/改写 "throws when type is not accounts" 与 "throws when type key missing" 两个用例
   - 新增用例：顶层无 `type` 但 `accounts.accounts` 结构完整的「完整数据」导出可成功解析（`export.type` 为 null，账号正常解析）

## 验收标准

- [ ] 顶层无 `type` 的完整导出 JSON（含合法 `accounts.accounts`）`fromJson` 解析成功，`type == null`
- [ ] 带 `type: "accounts"` 的旧格式仍解析成功，`type == 'accounts'`
- [ ] 缺失 `accounts` Map 或 `accounts.accounts` List 的文件仍抛 `FormatException`（中文提示不变）
- [ ] `flutter test test/features/backup/` 全绿
- [ ] `flutter analyze` 无新增告警

## 不在范围

- 不解析完整导出中的其他模块（书签、WebDAV 同步元数据等），维持现有"只取账号+标签"策略
- 不修改 `docs/API 文档/export-json-data.md`（该文档定位为「仅账号数据」格式参考）
- 不改动 merger / mapper / repository 层

## 开放问题

无 — 需求由用户实测明确，无阻塞决策。
