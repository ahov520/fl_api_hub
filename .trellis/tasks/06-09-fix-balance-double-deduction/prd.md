# 修复账号与Key余额双重扣减

## Goal

修正账号页面与 Key 层"余额/剩余额度"的双重扣减缺陷。`quota`（账号）/ `remain_quota`（Key）
本身已是剩余额度，当前代码错误地再减去 `used_quota`（历史累计消耗），导致展示余额偏小。

## Confirmed Facts（已从代码确认，详见 research/balance-data-flow.md）

- `UserInfoDto.quota` ← `/api/user/self` 的 `quota`，New API 家族语义为**当前剩余额度**。
- `TokenDto.remainQuota` ← `remain_quota`，DTO 注释明确为 **"Remaining quota"（剩余额度）**。
- `ApiKeyApiMapper:25` 把 `remainQuota`（剩余）赋给 `ApiKey.quota`，但该字段注释误写 "Quota limit"。
- 缺陷 3 处：①`account_api_mapper.dart:50` ②`key_quota_grid.dart:75` ③`api_key.dart:82`。
- 显示层 `account_card.dart` 直接读 `account.balance`，无二次计算；修数据层即可。
- 受影响测试：`account_api_mapper_test.dart`、`api_key_test.dart`。

## Decisions（已确认）

1. **修复范围 = 彻底修复（不重命名字段）**：3 处缺陷全部修正，并把
   `ApiKey.quota` / `UserInfoDto.quota` 的误导性注释订正为"剩余额度"语义。
   不重命名字段，以控制改动面与回归风险。
2. **不拆 subtasks**：三处属同一类 bug、强内聚、改动极小，单任务内分两批次实施
   （账号层 / Key 层）。
3. Sub2API：账号走 `balance` 分支不受影响；Key 层 `remainQuota` 已 ×500000 归一化为
   剩余额度，与 Common 家族修复逻辑一致，无需特殊处理。

## Requirements

- 账号层 `computeBalance`：剩余余额 = `quota / quotaPerUnit`（不再减 `used_quota`）；
  保留 `balance` 优先分支、`quota == null` / `quotaPerUnit <= 0` 的空值保护；
  `used_quota` 缺失不再阻断余额计算。
- Key 层"剩余额度" = `quota`（即 `remain_quota`）/ 500000，不再减 `used_quota`；
  "已用额度"列仍独立显示 `used_quota`（不动）。
- `ApiKey.remainingQuota` getter 改为直接返回 `quota`（unlimited 时仍为 null）。
- 订正 `ApiKey.quota`、`UserInfoDto.quota` 的英文注释为"剩余额度"语义。
- 同步更新受影响单元测试断言。

## Acceptance Criteria

- [ ] 账号卡片余额 = 站点返回的剩余额度（不再扣减历史消耗）。
- [ ] Key 卡片"剩余额度" = `remain_quota`（不再扣减）；"已用额度"仍 = `used_quota`。
- [ ] `ApiKey.remainingQuota` 返回 `quota`（200 已用、1000 剩余的样例返回 1000）。
- [ ] `account_api_mapper.dart` / `user_info_dto.dart` / `api_key.dart` 的相关注释语义正确。
- [ ] `account_api_mapper_test.dart`、`api_key_test.dart` 断言更新并通过。
- [ ] `flutter analyze` 无 warning，`flutter test` 全绿。

## Out of Scope

- 不改 `used_quota` 字段的解析与存储。
- 不重命名 `ApiKey.quota` 等字段。
- 不新增余额相关其他功能。
