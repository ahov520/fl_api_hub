# Implement: 修复账号与Key余额双重扣减

> 单任务两批次，不拆 subtasks。先实现再跑测。参考 design.md 与 research/balance-data-flow.md。

## 批次 1：账号层

- [ ] 1.1 `lib/features/accounts/data/models/account_api_mapper.dart`
  - `computeBalance`：删除 `usedQuota` 读取与其 null 检查；返回 `quota / quotaPerUnit`。
  - 更新函数 doc 注释（第 33-43 行）为 `quota / quotaPerUnit`，删除 "quota - used_quota" 描述。
- [ ] 1.2 `lib/core/network/dto/user_info_dto.dart:19`
  - 订正 `quota` 字段注释为"剩余额度（已是可用余额，token 单位）"。
- [ ] 1.3 更新 `test/features/accounts/data/models/account_api_mapper_test.dart`
  - L72-76：测试名去掉 "- usedQuota"，断言 `998.0` → `1000.0`。
  - L78-82：断言 `6.0` → `8.0`。
  - L89-92 `returns null when usedQuota is missing`：改写为「usedQuota 缺失仍按 quota 计算」，
    `UserInfoDto(quota: 1000.0)` → 期望 `1000.0 / 500000 = 0.002`。
  - L109-112 `allows negative derived balance`：删除或改写为正常用例
    （`quota` 本身是剩余，不再出现因减法导致的负值）。
  - L66-70（balance 优先分支）、L94-107（quota/qpu 空值保护）保持通过。
- [ ] 1.4 更新 `test/features/accounts/presentation/providers/accounts_notifier_test.dart`
  - ⚠️ **规划初稿遗漏**：该集成测试经 `accounts_notifier.dart:390` 间接依赖
    `computeBalance`，初版测试清单未覆盖。教训：修改被多处间接调用的核心计算函数时，
    必须全局追踪调用链上的所有测试（含集成/provider 测试），而非仅单元测试。
  - 5 处 balance 断言随新公式更新：998→1000、1→2、3→4、998→1000；
    deep-equals 用例 fixture `already.balance` 998→1000（否则计算值变化会误触发 update）。

## 批次 2：Key 层

- [ ] 2.1 `lib/features/keys/presentation/widgets/key_quota_grid.dart:73-77`
  - `_remainingQuota`：`remaining = apiKey.quota! / kDefaultQuotaPerUnit`；`_usedQuota` 不动。
- [ ] 2.2 `lib/features/keys/domain/entities/api_key.dart`
  - L82 `remainingQuota` getter → `return quota;`，更新 L81 注释。
  - L23 `quota` 字段注释 "Quota limit" → "Remaining quota (maps server remain_quota)"。
- [ ] 2.3 更新 `test/features/keys/domain/entities/api_key_test.dart:44-55`
  - `remainingQuota` 断言 `800` → `1000`；unlimited（quota=null）→ null 保持。

## 验证（每批完成后）

```bash
dart format lib test
flutter analyze                                  # 必须 0 warning
flutter test test/features/accounts/data/models/account_api_mapper_test.dart
flutter test test/features/keys/domain/entities/api_key_test.dart
flutter test                                     # 全量回归
```

## 手动验证建议（可选）

- 运行 app，进入账号页：余额应 = 站点剩余额度，原"余额不足"误判恢复正常。
- 进入某账号 Key 列表：「剩余额度」= remain_quota，「已用额度」= used_quota，两者独立。

## 风险文件 / 回滚点

- 三处改动彼此独立，任一异常可单文件 `git checkout -- <file>` 回退。
- 无持久化结构变更、无数据迁移。

## 完成前检查

- [ ] `flutter analyze` clean、`flutter test` 全绿。
- [ ] 验收标准（prd.md）逐条满足。
- [ ] dart format 已执行。
