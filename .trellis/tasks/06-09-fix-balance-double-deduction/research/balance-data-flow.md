# Research: 余额计算数据流与双重扣减缺陷定位

> 本文件承载脑暴阶段收集的全部代码证据，供实现/检查 sub-agent 获得完整上下文。
> 所有结论均标注来源 `文件:行`，基于当前磁盘状态（2026-06-09）。

## 1. 核心结论

`quota`（账号层）与 `remain_quota`（Key 层）**本身已是"剩余额度"**。当前代码再减去
`used_quota`（历史累计消耗），属于**双重扣减**，导致展示余额偏小。

## 2. 字段语义表

| DTO 字段 | 映射的 API 字段 | 真实语义 | 来源 |
|---|---|---|---|
| `UserInfoDto.quota` | `/api/user/self` 的 `quota` | New API 家族中为**当前剩余可用额度** | `user_info_dto.dart:20,51` |
| `UserInfoDto.usedQuota` | `used_quota` | 历史累计消耗（只增不减） | `user_info_dto.dart:23,52` |
| `UserInfoDto.balance` | `balance` | 站点直接给出的余额（USD），少数 fork | `user_info_dto.dart:26,53` |
| `TokenDto.remainQuota` | `remain_quota`(Common) / `quota`USD(Sub2API) | **剩余额度**（DTO 注释明确 "Remaining quota"） | `token_dto.dart:28-32` |
| `TokenDto.usedQuota` | `used_quota` / `quota_used`USD | 该令牌历史累计消耗 | `token_dto.dart:34-38` |

> ⚠️ 语义错位：`ApiKeyApiMapper.toEntity` 把 `remainQuota`（剩余）赋给了 `ApiKey.quota`
> （`api_key_api_mapper.dart:25`），而 `ApiKey.quota` 的注释却写 "Quota limit"（总额度）
> （`api_key.dart:23`）。这是误导后来人的陷阱。

## 3. 缺陷定位表（3 处，同一类 bug）

| # | 层 | 文件:行 | 错误代码 | 正确逻辑 |
|---|---|---|---|---|
| ① | 账号 | `account_api_mapper.dart:50` | `(quota - usedQuota) / quotaPerUnit` | `quota / quotaPerUnit` |
| ② | Key 显示 | `key_quota_grid.dart:75` | `(apiKey.quota! - apiKey.usedQuota) / kDefaultQuotaPerUnit` | `apiKey.quota! / kDefaultQuotaPerUnit` |
| ③ | Key 实体 | `api_key.dart:82` | `quota != null ? quota! - usedQuota : null` | `quota`（直接返回，null 时仍为 null） |

## 4. 数据流追踪

### 账号层
```
GET /api/user/self → UserInfoDto.fromJson (quota, used_quota, balance)
  → AccountApiMapper.computeBalance(dto, quotaPerUnit)   [缺陷①]
  → accounts_notifier.dart:390 _syncAccountInfo
  → account.copyWith(balance: derivedBalance)            [account.balance]
  → account_card.dart:409 直接显示 account.balance        [无二次计算]
```
- `balance != null` 时 computeBalance 直接返回 balance（Sub2API `/api/v1/auth/me` 走此分支，**不受影响**）。
- `quotaPerUnit` 来自 `_resolveQuotaPerUnit`（站点 `quota_per_unit` 或默认 500000），`accounts_notifier.dart:371`。

### Key 层
```
GET /api/token/ → TokenDto.fromJson (remain_quota→remainQuota, used_quota→usedQuota)
  → ApiKeyApiMapper.toEntity: ApiKey.quota = remainQuota, ApiKey.usedQuota = usedQuota
                                                          [api_key_api_mapper.dart:25-26]
  → key_quota_grid.dart "剩余额度"列 = _remainingQuota    [缺陷②]
  → key_quota_grid.dart "已用额度"列 = usedQuota / 500000 [正确，独立显示，不动]
  → ApiKey.remainingQuota getter                          [缺陷③, 当前无 UI 引用]
```

## 5. 显示层副作用（正向）

`account_card.dart:351,432,440` 以 `account.balance <= 1.0` 触发橙色"余额不足"警告。
修复后余额变大（不再扣减历史消耗），原本被误判的账号会自动恢复"正常"显示。

## 6. 行为变化（需在测试中体现）

修复 ① 后，`computeBalance` 不再读取 `usedQuota`：
- 旧：`quota` 或 `usedQuota` 任一缺失 → 返回 null。
- 新：仅 `quota` 缺失或 `quotaPerUnit <= 0` → 返回 null；`usedQuota` 缺失**不再**影响余额。
- 这是改进：更多只返回 `quota` 的站点也能展示余额。

## 7. 受影响测试

| 测试文件 | 断言 | 旧值 | 新值 |
|---|---|---|---|
| `account_api_mapper_test.dart:75` | `quota=5e8,used=1e6` | `998.0` | `1000.0` |
| `account_api_mapper_test.dart:81` | `quota=2e6,used=5e5,qpu=25e4` | `6.0` | `8.0` |
| `account_api_mapper_test.dart:89-92` | usedQuota 缺失 | `null` | `0.002`（重写为"仍可计算"） |
| `account_api_mapper_test.dart:109-112` | "负余额/超用" | `-2.0` | 语义失效，重写为正常用例 |
| `api_key_test.dart:45` | `quota=1000,used=200` | `800` | `1000` |

## 8. 兼容性确认

- **Sub2API 账号**：走 `balance` 分支，不受影响。
- **Sub2API Key**：`quota`USD 在 `token_dto.dart:_parseQuota` 已 ×500000 转为 `remainQuota`，语义与 Common 一致，修复逻辑通用。
- **unlimited**：`ApiKeyApiMapper:25` 中 `unlimitedQuota ? null : remainQuota`，`quota == null` → Key 显示"无限额度"，getter 返回 null，均保持。
