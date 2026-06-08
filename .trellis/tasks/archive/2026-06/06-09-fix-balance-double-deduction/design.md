# Design: 修复账号与Key余额双重扣减

## 1. 根因

`quota`（账号）/ `remain_quota`（Key）的语义是**剩余额度**，但计算公式当作"总额度"再减
`used_quota`，造成双重扣减。修复 = 去掉减法，直接使用 `quota`。详见
`research/balance-data-flow.md`。

## 2. 修复方案（彻底修复，不重命名）

### ① 账号层 — `lib/features/accounts/data/models/account_api_mapper.dart`
```dart
// before (L44-51)
static double? computeBalance(UserInfoDto dto, double quotaPerUnit) {
  if (dto.balance != null) return dto.balance;
  final quota = dto.quota;
  final usedQuota = dto.usedQuota;
  if (quota == null || usedQuota == null) return null;
  if (quotaPerUnit <= 0) return null;
  return (quota - usedQuota) / quotaPerUnit;
}

// after
static double? computeBalance(UserInfoDto dto, double quotaPerUnit) {
  if (dto.balance != null) return dto.balance;
  final quota = dto.quota;
  if (quota == null) return null;
  if (quotaPerUnit <= 0) return null;
  return quota / quotaPerUnit;   // quota 已是剩余额度，不再减历史消耗
}
```
同步更新函数 doc 注释（第 33-43 行）："derives it as `quota / quotaPerUnit`"。

### ② Key 层显示 — `lib/features/keys/presentation/widgets/key_quota_grid.dart`
```dart
// before (L73-77)
String get _remainingQuota {
  if (apiKey.quota == null) return '无限额度';
  final remaining = (apiKey.quota! - apiKey.usedQuota) / kDefaultQuotaPerUnit;
  return '\$${remaining.toStringAsFixed(2)}';
}
// after：remaining = apiKey.quota! / kDefaultQuotaPerUnit;
```
"已用额度"列 `_usedQuota`（L79-80）保持不变。

### ③ Key 实体 — `lib/features/keys/domain/entities/api_key.dart`
```dart
// before (L81-82)
/// Remaining quota. `null` if quota is unlimited.
int? get remainingQuota => quota != null ? quota! - usedQuota : null;
// after
/// Remaining quota (already the server's remain_quota). `null` if unlimited.
int? get remainingQuota => quota;
```

### 注释订正
- `api_key.dart:23`：`ApiKey.quota` 注释 "Quota limit" → "Remaining quota (maps from server `remain_quota`); `null` means unlimited"。
- `user_info_dto.dart:19`：`UserInfoDto.quota` 注释 "Total quota allocation" → "Remaining quota (already the available balance in token units)"。

## 3. 数据流（修复后）

```
账号: /api/user/self → quota → computeBalance = quota/qpu → account.balance → 卡片显示
Key : /api/token/ → remain_quota → ApiKey.quota → "剩余额度" = quota/500000
```
显示层无改动；`balance` 优先分支、unlimited 分支均保持原行为。

## 4. 行为变化

`computeBalance` 不再依赖 `used_quota`：旧逻辑 `used_quota` 缺失会返回 null，新逻辑只要
`quota` 存在即可算出余额。属功能改进，需在测试中体现（见 implement.md）。

## 5. 兼容性 / 回滚

- **兼容**：Sub2API 账号走 `balance` 分支不变；Sub2API/Common 的 Key `remainQuota` 已归一化；unlimited 分支不变。
- **回滚**：三处改动相互独立，可单点 `git checkout -- <file>` 回退；无数据迁移、无持久化结构变更。

## 6. 风险

| 风险 | 评估 | 缓解 |
|---|---|---|
| 误判某站点 `quota` 实为"总额度" | 低（用户已确认 New API 语义为剩余） | 保留 `balance` 优先分支；如有反例后续按站点家族分流 |
| 测试断言遗漏 | 低 | implement.md 列出逐条断言新值 |
