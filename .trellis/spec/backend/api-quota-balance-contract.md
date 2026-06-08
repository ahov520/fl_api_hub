# API Quota / Balance Contract

> How upstream `quota` / `remain_quota` fields map to the displayed balance.
> Captured from task `06-09-fix-balance-double-deduction` (a double-deduction bug).

---

## Scenario: Deriving available balance (New API / One API family + Sub2API)

### 1. Scope / Trigger

- Trigger: cross-layer request/response contract — how upstream account/token
  quota fields are interpreted when computing the balance shown in the UI.
- Family: new-api, one-api, veloera, done-hub, one-hub, wong, anyrouter; plus Sub2API.

### 2. Signatures

- `AccountApiMapper.computeBalance(UserInfoDto dto, double quotaPerUnit) -> double?`
  — `lib/features/accounts/data/models/account_api_mapper.dart`
- `ApiKey.quota` (int?, mapped from `TokenDto.remainQuota`) and
  `ApiKey.remainingQuota -> int?` — `lib/features/keys/domain/entities/api_key.dart`
- `KeyQuotaGrid._remainingQuota` (display) — `lib/features/keys/presentation/widgets/key_quota_grid.dart`

### 3. Contracts

Account (`GET /api/user/self` → `UserInfoDto`):

| Field | Meaning | Note |
|-------|---------|------|
| `quota` | **Remaining** balance in token units | NOT total allocation |
| `used_quota` | Historical cumulative consumption | Independent, monotonic |
| `balance` | Explicit USD balance (rare forks / Sub2API `/auth/me`) | Trusted as-is when present |

Token (`GET /api/token/` → `TokenDto`):

| Field | Meaning | Note |
|-------|---------|------|
| `remain_quota` | **Remaining** quota in token units (`-1` = unlimited) | Sub2API `quota` USD × 500000 |
| `used_quota` | Historical cumulative consumption | Sub2API `quota_used` USD × 500000 |

Conversion: `1 USD = 500000 token units` (`kDefaultQuotaPerUnit`), overridable by
site-reported `quota_per_unit`.

### 4. Validation & Error Matrix

| Condition | Result |
|-----------|--------|
| `dto.balance != null` | return `balance` (skip quota math) |
| `quota == null` | return `null` (balance unknown) |
| `quotaPerUnit <= 0` | return `null` (invalid factor) |
| `used_quota` missing | irrelevant — NOT required for balance |

### 5. Good/Base/Bad Cases

- Good: `quota=500000000, qpu=500000` → balance `1000.0` USD.
- Base: `balance=12.34` present → returns `12.34` regardless of quota.
- Bad (the bug this prevents): `quota=500000000, used=1000000` → must be `1000.0`, NOT `998.0`.

### 6. Tests Required

- `account_api_mapper_test.dart`: balance = quota/qpu; used_quota ignored; null when
  quota missing or qpu ≤ 0; explicit-balance branch wins.
- `api_key_test.dart`: `remainingQuota == quota` (not `quota - used`).
- `accounts_notifier_test.dart`: integration — `patched.balance` reflects quota/qpu.
  ⚠️ This is an **indirect caller** of `computeBalance`; its assertions must be updated
  whenever the formula changes (this was missed initially and caused 5 test failures).

### 7. Wrong vs Correct

#### Wrong
```dart
return (quota - usedQuota) / quotaPerUnit;        // double-deducts history
int? get remainingQuota => quota! - usedQuota;    // same bug at entity level
```

#### Correct
```dart
return quota / quotaPerUnit;   // `quota` is ALREADY the remaining balance
int? get remainingQuota => quota;
```

> **Warning**: `quota` / `remain_quota` are already *remaining* balances. Subtracting
> `used_quota` double-deducts and understates the balance. `used_quota` feeds the
> separate "used" display only.
