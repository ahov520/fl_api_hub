# 导出账号数据 — JSON 格式参考文档

## 概述

本文档面向开发者，描述「导入/导出 → 导出数据 → 账号数据」功能导出的 JSON 文件结构。

导出入口函数：`src/features/ImportExport/utils.ts` → `handleExportAccounts()`
导出类型：`BackupAccountsPartialV2`（定义于 `src/services/importExport/importExportService.ts`）
备份版本常量：`BACKUP_VERSION = "2.0"`
下载文件名格式：`accounts-backup-YYYY-MM-DD.json`

---

## 顶层结构

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `version` | `string` | 是 | 备份格式版本号，当前为 `"2.0"` |
| `timestamp` | `number` | 是 | 导出时间的 Unix 毫秒时间戳 |
| `type` | `string` | 是 | 固定为 `"accounts"`，标识此备份为纯账号数据 |
| `accounts` | `AccountStorageConfig` | 是 | 账号与书签存储配置 |
| `tagStore` | `TagStore` | 是 | 全局标签存储快照（新版本导出始终包含） |

### JSON 示例（顶层）

```json
{
  "version": "2.0",
  "timestamp": 1735689600000,
  "type": "accounts",
  "accounts": { ... },
  "tagStore": { ... }
}
```

---

## AccountStorageConfig

定义：`src/types/index.ts` → `AccountStorageConfig`

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `accounts` | `SiteAccount[]` | 是 | 站点账号列表 |
| `bookmarks` | `SiteBookmark[]` | 是 | 书签列表 |
| `pinnedAccountIds` | `string[]` | 是 | 置顶条目 ID 列表（新置顶在前） |
| `orderedAccountIds` | `string[]` | 是 | 手动排序 ID 列表（最新变更在前） |
| `deletedEntryRecords` | `Record<string, DeletedEntryRecord>` | 可选 | 删除记录，用于 WebDAV 合并同步时避免恢复已删除条目 |
| `last_updated` | `number` | 是 | 最后更新时间戳（毫秒） |

---

## SiteAccount

定义：`src/types/index.ts` → `SiteAccount`

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | `string` | 是 | 此项唯一标识 |
| `site_name` | `string` | 是 | 站点自定义名称 |
| `site_url` | `string` | 是 | 站点 URL |
| `health` | `HealthStatus` | 是 | 站点健康状态 |
| `site_type` | `AccountSiteType` | 是 | 账号站点类型（如 `"new-api"`、`"one-api"`、`"unknown"` 等） |
| `exchange_rate` | `number` | 是 | 人民币与美元充值比例（CNY per USD） |
| `account_info` | `AccountInfo` | 是 | 账号核心信息 |
| `last_sync_time` | `number` | 是 | 最后同步时间戳（毫秒） |
| `updated_at` | `number` | 是 | 更改时间戳（毫秒） |
| `user_updated_at` | `number` | 是 | 用户意图更改时间戳（毫秒） |
| `created_at` | `number` | 是 | 创建时间戳（毫秒） |
| `notes` | `string` | 是 | 备注；默认空字符串 |
| `tagIds` | `string[]` | 是 | 关联的全局标签 ID 列表；引用 `TagStore.tagsById` 的键 |
| `disabled` | `boolean` | 是 | 是否已禁用；默认 `false` |
| `excludeFromTotalBalance` | `boolean` | 是 | 是否排除出总计余额；默认 `false` |
| `excludeFromTodayIncome` | `boolean` | 是 | 是否排除出今日收入；默认 `false` |
| `authType` | `AuthTypeEnum` | 是 | 认证方式：`"access_token"` 或 `"cookie"` |
| `cookieAuth` | `CookieAuthConfig` | 可选 | Cookie 认证配置；仅 `authType === "cookie"` 时存在 |
| `sub2apiAuth` | `Sub2ApiAuthConfig` | 可选 | Sub2API 刷新令牌配置；仅 Sub2API 账号存在 |
| `checkIn` | `CheckInConfig` | 是 | 签到配置与状态 |
| `manualBalanceUsd` | `string` | 可选 | 用户手动设置的余额（USD）；无此字段则使用自动获取的配额 |
| `configVersion` | `number` | 可选 | 配置版本号，用于迁移追踪 |
| `emoji` | `string` | 可选，已废弃 | 旧版 Emoji 图标，不再使用 |
| `tags` | `string[]` | 可选，已废弃 | 旧版按名称存储的标签；由 `tagIds` 替代 |
| `can_check_in` | `boolean` | 可选，已废弃 | 旧版签到标记；由 `checkIn.siteStatus.isCheckedInToday` 替代 |
| `supports_check_in` | `boolean` | 可选，已废弃 | 旧版签到支持标记；由 `checkIn` 对象替代 |

---

### HealthStatus

定义：`src/types/index.ts` → `HealthStatus`

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `status` | `SiteHealthStatus` | 是 | 健康状态枚举：`"healthy"` / `"warning"` / `"error"` / `"unknown"` |
| `reason` | `string` | 可选 | 状态原因描述 |
| `code` | `HealthStatusCode` | 可选 | 机器可读的状态码（可用于 UI 跳转等） |

---

### AccountInfo

定义：`src/types/index.ts` → `AccountInfo`

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | `string` | 是 | 账号身份标识（站点内稳定字符串） |
| `access_token` | `string` | 是 | 访问令牌 |
| `username` | `string` | 是 | 用户名 |
| `quota` | `number` | 是 | 总余额点数 |
| `today_prompt_tokens` | `number` | 是 | 今日 prompt tokens 用量 |
| `today_completion_tokens` | `number` | 是 | 今日 completion tokens 用量 |
| `today_quota_consumption` | `number` | 是 | 今日已消耗配额 |
| `today_requests_count` | `number` | 是 | 今日请求次数 |
| `today_income` | `number` | 是 | 今日收入（充值 + 签到） |

---

### CheckInConfig

定义：`src/types/index.ts` → `CheckInConfig`

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `enableDetection` | `boolean` | 是 | 是否启用签到检测与监控 |
| `autoCheckInEnabled` | `boolean` | 可选 | 是否启用自动签到；默认 `true`（仅当 `enableDetection` 为 `true` 时有效） |
| `siteStatus` | `object` | 可选 | 内置站点签到状态（API 驱动） |
| `siteStatus.isCheckedInToday` | `boolean` | 可选 | `true`=已签到, `false`=未签到, `undefined`=未知 |
| `siteStatus.lastCheckInDate` | `string` | 可选 | 最后签到日期（格式：`YYYY-MM-DD`） |
| `siteStatus.lastDetectedAt` | `number` | 可选 | 最后检测时间戳（毫秒），用于判断状态是否过期 |
| `customCheckIn` | `object` | 可选 | 自定义签到 URL 配置与状态，可与内置签到共存 |
| `customCheckIn.url` | `string` | 可选 | 自定义签到 URL |
| `customCheckIn.turnstilePreTrigger` | `TurnstilePreTrigger` | 可选 | Turnstile 预触发配置（高级场景） |
| `customCheckIn.redeemUrl` | `string` | 可选 | 自定义兑换/充值 URL |
| `customCheckIn.openRedeemWithCheckIn` | `boolean` | 可选 | 打开签到 URL 时是否同时打开兑换页面；默认 `true` |
| `customCheckIn.isCheckedInToday` | `boolean` | 可选 | 今日是否已通过自定义 URL 签到 |
| `customCheckIn.lastCheckInDate` | `string` | 可选 | 自定义签到最后签到日期（`YYYY-MM-DD`） |

---

### CookieAuthConfig

定义：`src/types/index.ts` → `CookieAuthConfig`

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `sessionCookie` | `string` | 是 | Cookie 会话字符串，用于多账号 Cookie 认证隔离 |

---

### Sub2ApiAuthConfig

定义：`src/types/index.ts` → `Sub2ApiAuthConfig`

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `refreshToken` | `string` | 是 | 可导出的刷新令牌，用于扩展管理的 Sub2API 会话 |
| `tokenExpiresAt` | `number` | 可选 | 访问令牌过期时间戳（毫秒），用于主动刷新 |

---

## SiteBookmark

定义：`src/types/index.ts` → `SiteBookmark`

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | `string` | 是 | 书签唯一标识 |
| `name` | `string` | 是 | 书签名称 |
| `url` | `string` | 是 | 书签 URL |
| `tagIds` | `string[]` | 是 | 关联的全局标签 ID 列表；引用 `TagStore.tagsById` 的键 |
| `notes` | `string` | 是 | 备注；默认空字符串 |
| `created_at` | `number` | 是 | 创建时间戳（毫秒） |
| `updated_at` | `number` | 是 | 更新时间戳（毫秒） |

---

## TagStore & Tag

定义：`src/types/index.ts` → `TagStore` / `Tag`

### TagStore

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `version` | `number` | 是 | 标签存储版本号 |
| `tagsById` | `Record<string, Tag>` | 是 | 标签 ID 到标签对象的映射 |

### Tag

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | `string` | 是 | 标签唯一标识 |
| `name` | `string` | 是 | 标签名称 |
| `createdAt` | `number` | 是 | 创建时间戳（毫秒） |
| `updatedAt` | `number` | 是 | 更新时间戳（毫秒） |

---

## DeletedEntryRecord

定义：`src/types/index.ts` → `DeletedEntryRecord`

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `kind` | `"account"` \| `"bookmark"` | 是 | 被删除条目的类型 |
| `deletedAt` | `number` | 是 | 删除时间戳（毫秒） |
| `entryUpdatedAt` | `number` | 是 | 删除前条目最后更新时间戳（毫秒） |

---

## 完整 JSON 示例

```json
{
  "version": "2.0",
  "timestamp": 1735689600000,
  "type": "accounts",
  "accounts": {
    "accounts": [
      {
        "id": "account-access-token-1",
        "site_name": "我的 New API",
        "site_url": "https://newapi.example.com",
        "health": {
          "status": "healthy"
        },
        "site_type": "new-api",
        "authType": "access_token",
        "exchange_rate": 7.2,
        "disabled": false,
        "excludeFromTotalBalance": false,
        "excludeFromTodayIncome": false,
        "notes": "这是主力账号",
        "tagIds": ["tag-work", "tag-personal"],
        "account_info": {
          "id": "user-001",
          "access_token": "sk-xxxxxxxxxxxxxxxxxxxx",
          "username": "admin",
          "quota": 500000000,
          "today_prompt_tokens": 12345,
          "today_completion_tokens": 6789,
          "today_quota_consumption": 250000,
          "today_requests_count": 42,
          "today_income": 100000
        },
        "manualBalanceUsd": "50.00",
        "checkIn": {
          "enableDetection": true,
          "autoCheckInEnabled": true,
          "siteStatus": {
            "isCheckedInToday": true,
            "lastCheckInDate": "2025-01-01",
            "lastDetectedAt": 1735689600000
          },
          "customCheckIn": {
            "url": "https://newapi.example.com/checkin",
            "redeemUrl": "https://newapi.example.com/redeem",
            "openRedeemWithCheckIn": true,
            "isCheckedInToday": true,
            "lastCheckInDate": "2025-01-01"
          }
        },
        "last_sync_time": 1735689600000,
        "updated_at": 1735689600000,
        "user_updated_at": 1735689600000,
        "created_at": 1735689600000
      },
      {
        "id": "account-cookie-1",
        "site_name": "Cookie 站点",
        "site_url": "https://cookie-site.example.com",
        "health": {
          "status": "healthy"
        },
        "site_type": "one-api",
        "authType": "cookie",
        "exchange_rate": 7.2,
        "disabled": false,
        "excludeFromTotalBalance": false,
        "excludeFromTodayIncome": false,
        "notes": "",
        "tagIds": ["tag-personal"],
        "account_info": {
          "id": "user-002",
          "access_token": "sk-yyyyyyyyyyyyyyyyyyyy",
          "username": "cookie-user",
          "quota": 1000000,
          "today_prompt_tokens": 500,
          "today_completion_tokens": 300,
          "today_quota_consumption": 10000,
          "today_requests_count": 5,
          "today_income": 0
        },
        "cookieAuth": {
          "sessionCookie": "session=abc123; token=def456"
        },
        "checkIn": {
          "enableDetection": false
        },
        "last_sync_time": 1735689600000,
        "updated_at": 1735689600000,
        "user_updated_at": 1735689600000,
        "created_at": 1735689600000
      },
      {
        "id": "account-disabled-1",
        "site_name": "已禁用账号",
        "site_url": "https://disabled.example.com",
        "health": {
          "status": "error",
          "reason": "Token 已过期"
        },
        "site_type": "unknown",
        "authType": "access_token",
        "exchange_rate": 7.2,
        "disabled": true,
        "excludeFromTotalBalance": true,
        "excludeFromTodayIncome": true,
        "notes": "此账号已废弃",
        "tagIds": [],
        "account_info": {
          "id": "user-003",
          "access_token": "sk-zzzzzzzzzzzzzzzzzzzz",
          "username": "disabled-user",
          "quota": 0,
          "today_prompt_tokens": 0,
          "today_completion_tokens": 0,
          "today_quota_consumption": 0,
          "today_requests_count": 0,
          "today_income": 0
        },
        "checkIn": {
          "enableDetection": false
        },
        "last_sync_time": 1735689600000,
        "updated_at": 1735689600000,
        "user_updated_at": 1735689600000,
        "created_at": 1735689600000
      },
      {
        "id": "account-sub2api-1",
        "site_name": "Sub2API 站点",
        "site_url": "https://sub2api.example.com",
        "health": {
          "status": "healthy"
        },
        "site_type": "sub2api",
        "authType": "access_token",
        "exchange_rate": 7.0,
        "disabled": false,
        "excludeFromTotalBalance": false,
        "excludeFromTodayIncome": false,
        "notes": "",
        "tagIds": [],
        "account_info": {
          "id": "user-004",
          "access_token": "sk-aaaaaaaaaaaaaaaaaaaa",
          "username": "sub2api-user",
          "quota": 9999999,
          "today_prompt_tokens": 0,
          "today_completion_tokens": 0,
          "today_quota_consumption": 0,
          "today_requests_count": 0,
          "today_income": 0
        },
        "sub2apiAuth": {
          "refreshToken": "rt_xxxxxxxxxxxxxxxxxxxx",
          "tokenExpiresAt": 1735776000000
        },
        "checkIn": {
          "enableDetection": false
        },
        "last_sync_time": 1735689600000,
        "updated_at": 1735689600000,
        "user_updated_at": 1735689600000,
        "created_at": 1735689600000
      }
    ],
    "bookmarks": [
      {
        "id": "bookmark-1",
        "name": "API 文档",
        "url": "https://newapi.example.com/docs",
        "tagIds": ["tag-work"],
        "notes": "常用开发文档",
        "created_at": 1735689600000,
        "updated_at": 1735689600000
      }
    ],
    "pinnedAccountIds": ["account-access-token-1", "account-cookie-1"],
    "orderedAccountIds": [
      "account-access-token-1",
      "account-cookie-1",
      "account-sub2api-1",
      "account-disabled-1"
    ],
    "deletedEntryRecords": {
      "old-deleted-account-id": {
        "kind": "account",
        "deletedAt": 1735603200000,
        "entryUpdatedAt": 1735516800000
      }
    },
    "last_updated": 1735689600000
  },
  "tagStore": {
    "version": 1,
    "tagsById": {
      "tag-work": {
        "id": "tag-work",
        "name": "工作",
        "createdAt": 1735603200000,
        "updatedAt": 1735603200000
      },
      "tag-personal": {
        "id": "tag-personal",
        "name": "个人",
        "createdAt": 1735603200000,
        "updatedAt": 1735603200000
      }
    }
  }
}
```

---

## 变更历史

| 日期 | 版本 | 说明 |
|------|------|------|
| 2026-06-10 | 1.0 | 初始版本，基于 `BackupAccountsPartialV2` 和 `BACKUP_VERSION = "2.0"` |