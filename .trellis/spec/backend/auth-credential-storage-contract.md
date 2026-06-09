# Auth Credential Storage Contract

> How an account's credential is persisted on `Account` and injected as an HTTP
> auth header by `AuthInterceptor`. Get the cookie shape wrong and the header
> silently double-prefixes (`session=session=...`), so upstream auth fails with
> no obvious error.

## Scenario: Storing & injecting per-account credentials

### 1. Scope / Trigger

- Trigger: cross-layer credential contract — **any** path that writes
  `Account.accessToken` (manual add/edit, plugin import, cookie→token exchange)
  must store the value in the exact shape `AuthInterceptor` expects.
- Layers: domain entity (`Account`) → persistence (`AccountMapper`) → network
  (`AuthInterceptor`).

### 2. Signatures

- `Account.accessToken : String?`, `Account.authType : AuthType` —
  `lib/features/accounts/domain/entities/account.dart`
- `enum AuthType { accessToken, cookie, none }` —
  `lib/core/network/site_type.dart`
- `AuthInterceptor.onRequest(RequestOptions, RequestInterceptorHandler)` —
  `lib/core/network/auth_interceptor.dart`; reads `options.extra`:
  - `apiAuthToken : String?` — the credential value
  - `apiAuthType : String?` — an `AuthType.name` (`'accessToken'` | `'cookie'` | `'none'`)
  - `apiUserId : int?`

### 3. Contracts (authType → injected header)

| authType | Header injected | Stored `accessToken` shape |
|----------|-----------------|----------------------------|
| `accessToken` | `Authorization: Bearer <token>` | the raw bearer token |
| `cookie` | `Cookie: session=<token>` | **raw session value only — NO `session=` prefix** |
| `none` | (none) | n/a |

- When `apiUserId > 0`, also injects `New-API-User: <id>`.
- When `apiAuthToken` is `null` or empty, **no auth header is injected** for any
  `authType`.

### 4. Validation & Error Matrix

| Condition | Result |
|-----------|--------|
| cookie account stores `accessToken = "session=abc"` | interceptor emits `Cookie: session=session=abc` → upstream auth fails |
| `accessToken` null/empty | no auth header; cookie/token sites reject; check-in short-circuits to `skipped` (token guard in `check_in_notifier.dart`) |
| `authType` string not a valid `AuthType.name` | `AuthType.values.byName` throws — only ever persist `AuthType.name` values |

### 5. Good / Base / Bad cases

- Good (cookie): plugin export `cookieAuth.sessionCookie = "session=abc123"` →
  strip prefix → store `accessToken = "abc123"` → `Cookie: session=abc123`. ✓
- Base (access token): store `accessToken = "sk-xxxx"`, `authType = accessToken`
  → `Authorization: Bearer sk-xxxx`. ✓
- Bad: store the full `"session=abc123"` for a cookie account → double prefix. ✗

### 6. Tests Required

- `AuthInterceptor` unit test: per `AuthType`, assert the exact header emitted
  (incl. the `session=` prefix for cookie, and no header when token is empty).
  Assertion point: `options.headers['Cookie'] == 'session=<value>'`.
- Credential-writing mappers strip/store correctly. The plugin import mapper
  strips a leading `session=` before storing
  (`test/features/backup/data/models/plugin_account_mapper_test.dart`).
  Assertion point: `map['accessToken'] == '<value-without-prefix>'`.

### 7. Wrong vs Correct

#### Wrong
```dart
// Cookie account — stores the whole pair; the interceptor re-prefixes it.
account.copyWith(accessToken: 'session=abc123', authType: AuthType.cookie);
// → Cookie: session=session=abc123  (auth fails)
```

#### Correct
```dart
// Store only the raw session value; the interceptor adds `session=`.
final raw = pair.startsWith('session=')
    ? pair.substring('session='.length)
    : pair;
account.copyWith(accessToken: raw, authType: AuthType.cookie);
// → Cookie: session=abc123
```
