# Plugin Export Parse Contract

> How `PluginExport.fromJson` decides whether a file is a valid All-API-Hub
> browser-plugin export. The plugin has **two export flavors** and only one of
> them carries a top-level `type` key — gating on `type` rejects perfectly
> valid full-data exports (this shipped as a real bug once).

## Scenario: Parsing a plugin export file for import

### 1. Scope / Trigger

- Trigger: external-format contract — any change to the import validation in
  `PluginExport.fromJson` (`lib/features/backup/data/models/plugin_export_dto.dart`)
  or anything that re-introduces envelope-level gating.
- Layers: file datasource (raw JSON) → DTO parse (single validation gate) →
  merger/repository (consume parsed data, zero writes on failure).

### 2. Signatures

- `factory PluginExport.fromJson(Map<String, dynamic> json)` — throws
  `FormatException('不是有效的 All-API-Hub 导出文件')` on invalid input.
- `PluginExport.type : String?` — parsed metadata only; carries **no
  validation weight**.
- Caller contract: `plugin_import_repository_impl.dart` treats any
  `FormatException` as "not a plugin file" and aborts with zero writes.

### 3. Contracts (two export flavors, one parse path)

| Flavor | Top-level `type` | Shared structure |
|--------|------------------|------------------|
| Accounts-only export | `"accounts"` | `accounts.accounts[]`, `accounts.orderedAccountIds[]`, `tagStore.tagsById{}` |
| Full-data export | **key absent** | same nested `accounts` / `tagStore` structure |

- File validity is decided **only** by structure: `accounts` must be a `Map`
  and `accounts.accounts` must be a `List`. Nothing else gates.
- Reference for the accounts-only flavor: `docs/API 文档/export-json-data.md`.

### 4. Validation & Error Matrix

| Condition | Result |
|-----------|--------|
| `accounts` missing or not a `Map` | `FormatException` (Chinese message above) |
| `accounts.accounts` missing or not a `List` | `FormatException` |
| `type` absent / `null` / any other string | **parses fine** — never reject on `type` |
| empty `accounts.accounts` list | valid export with zero accounts |

### 5. Good / Base / Bad cases

- Good (full export): no `type`, valid `accounts.accounts` → parses,
  `export.type == null`. ✓
- Base (accounts-only): `type: "accounts"` → parses, `export.type == 'accounts'`. ✓
- Bad: re-adding `if (json['type'] != 'accounts') throw ...` → every full-data
  export is rejected as "not a plugin file". ✗

### 6. Tests Required

- `test/features/backup/data/models/plugin_export_dto_test.dart`:
  - full-data export without `type` parses; assertion point:
    `export.type == null` and accounts parsed.
  - structural failures still throw; assertion point:
    `throwsA(isA<FormatException>())` for missing `accounts` map / nested list.

### 7. Wrong vs Correct

#### Wrong
```dart
// Gates on envelope metadata that only one export flavor carries.
if (json['type'] != 'accounts') {
  throw const FormatException('不是有效的 All-API-Hub 导出文件');
}
```

#### Correct
```dart
// Validate structure only; `type` is parsed as nullable metadata.
final accountsConfig = json['accounts'];
if (accountsConfig is! Map) {
  throw const FormatException('不是有效的 All-API-Hub 导出文件');
}
final rawAccounts = accountsConfig['accounts'];
if (rawAccounts is! List) {
  throw const FormatException('不是有效的 All-API-Hub 导出文件');
}
```
