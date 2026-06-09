# 导入 All-API-Hub 插件导出数据

## Goal / 目标与用户价值

让用户把 **All-API-Hub 浏览器插件**导出的账号数据文件（`accounts-backup-YYYY-MM-DD.json`，备份格式 `version "2.0"` / `type "accounts"`）一键导入本 App，免去从插件迁移时逐个手动录入账号的成本。

## Confirmed Facts / 已确认事实（代码调研，非假设）

- 现有「设置 → 数据管理」= `BackupPage`（`lib/features/backup/presentation/pages/backup_page.dart`），含「创建备份 / 恢复数据 / 加密设置」三块。
- 现有备份是**自有 `.flhbkp` 格式**（envelope = metadata + 8 个 Hive box 的 raw map + SHA-256 checksum + 可选 AES 加密），与插件**明文 JSON v2.0** 完全不同，二者不可混用同一解析链路。
- 账号持久化经 `AccountMapper.toMap`（`lib/features/accounts/data/models/account_mapper.dart`）；标签经 `TagMapper.toMap`（`lib/features/tags/data/models/tag_mapper.dart`）。
- 合并写入 Hive 复用 `BackupHiveReader.writeData()`（不清空、按 `id` put）；选文件复用 `BackupFileDataSource.pickFile()`（`FileType.any`，已具备）。
- cookie 账号：session 值存在 `Account.accessToken`，`authType=cookie` 时 `auth_interceptor.dart:38-39` 拼成 `Cookie: session=<accessToken>`。
- `quota`(token 单位) → USD 固定除以 `kDefaultQuotaPerUnit`(500000)，且插件 `quota` 与本项目语义一致（已是剩余额度，不再减消耗）——见 `.trellis/spec/backend/api-quota-balance-contract.md`。
- `SiteType.value` 与插件 `site_type` 取值高度一致（`new-api`/`one-api`/`anyrouter`/`sub2api`/`unknown`…），可经 `SiteType.fromValue` 映射，未知值回退 `SiteType.unknown`。
- 本项目**无书签功能**、无 `deletedEntryRecords` / `excludeFromTodayIncome` / `health` 持久化、`Account` 无 sub2api `refreshToken` 字段。

## Requirements / 需求（产品决策已定）

1. **入口**：在 `BackupPage` 新增**独立 SectionCard**「从浏览器插件导入」，内含「导入 All-API-Hub 插件数据」条目。
2. **选文件**：复用 `pickFile()` 选取插件导出的 JSON 文件。
3. **校验**：解析并校验顶层 `type == "accounts"`；格式非法 / 非插件文件给出明确中文错误提示，不污染本地数据。
4. **字段映射**：按 `design.md` 的映射表把插件 `SiteAccount`/`Tag` 转换为本项目 `AccountMapper.toMap` / `TagMapper.toMap` 形状。
5. **账号去重**：业务键 = `baseUrl + username`；本地已存在则**跳过**（保留本地版本，绝不覆盖用户手动编辑）。
6. **标签去重**：按 `name`（不区分大小写）去重；本地已有同名标签则**复用本地标签 id**，并把账号 `tagIds` 重映射到本地 id；本地无同名则新增（沿用插件 tag id）。
7. **余额换算**：`balance = quota / 500000`（USD）；若插件 `manualBalanceUsd` 为非空字符串则解析后写入本项目 `manualBalanceUsd`。
8. **写入语义**：仅「合并追加」，**绝不清空**本地数据；无「全量替换」选项。
9. **ID 策略**：新增账号生成本项目 `Uuid().v4()`（不沿用插件 `account_xxx` id），与 `sortOrder` 一并追加在本地账号之后。
10. **结果摘要**：导入完成后展示「新增账号数 / 跳过账号数 / 新增标签数 / 复用标签数」。
11. **后台执行**：解析与映射在 `Isolate.run` 中进行（对齐现有 backup 大数据处理方式），避免卡 UI。

## Acceptance Criteria / 验收标准（可测试）

- [ ] `BackupPage` 出现「从浏览器插件导入」板块，点击可拉起文件选择器。
- [ ] 导入随附模板 `docs/API 文档/all-api-hub-export-accounts-template.json`：2 个账号成功落库，`name`/`baseUrl`/`siteType`/`accessToken`/`authType` 均正确。
- [ ] cookie 账号「Anyrouter」：`accessToken` = 剥离 `session=` 前缀后的值，`authType == AuthType.cookie`，`siteType == SiteType.anyrouter`。
- [ ] `disabled:false` → `enabled:true`（若文件含 `disabled:true` 则 `enabled:false`）。
- [ ] 账号 `tagIds` 全部指向本地 `tags` box 中真实存在的标签；同名标签不重复创建（如插件 `Coding` 标签）。
- [ ] 余额换算：`quota=2074349914` → `balance ≈ 4148.70` USD。
- [ ] **幂等**：连续导入同一文件两次，第二次全部按 `baseUrl+username` 跳过，账号总数不增。
- [ ] 导入过程与结果**不删除 / 不修改**本地既有账号与标签。
- [ ] 完成后结果页显示正确的摘要计数。
- [ ] `dart format .` 已执行、`flutter analyze` 0 warning、新增单测覆盖（DTO 解析 / 账号 mapper / 去重合并 / 余额换算）、`flutter test` 全绿。

## Out of Scope / 不做

- 书签（`bookmarks`）导入 —— 本项目无书签功能。
- `deletedEntryRecords` / WebDAV 合并同步语义。
- `excludeFromTodayIncome`、`health` 状态、Sub2API `sub2apiAuth.refreshToken` 的持久化（本项目 `Account` 无对应字段）—— 直接丢弃；sub2api 账号本身仍按普通账号导入。
- 导出为插件格式（本任务仅「导入」单向）。
- 「全量替换」导入模式。

## Open Questions / 实现默认假设（非阻塞，可 review 调整）

- `sub2apiAuth.refreshToken` 无本地字段 → 丢弃。
- `pinnedAccountIds` 不单独建模；统一按 `orderedAccountIds` 顺序生成 `sortOrder`，追加在本地账号最大 `sortOrder` 之后。
- 插件 `account_info.access_token` 与 cookie 账号的 `cookieAuth.sessionCookie` 互斥取用：`authType=cookie` 取 `sessionCookie`（剥前缀），否则取 `access_token`。
