# Testing Guidelines

> Conventions and gotchas for widget/unit tests. Read before writing or fixing tests.

---

## Hive Must Be Initialized for Pages That Read Persisted State

### The Contract

Any widget test that pumps a page which — directly or transitively — reads the
Hive-backed `app_data` box **must** initialize Hive in `setUp` and close it in
`tearDown`. This mirrors the canonical pattern in `test/widget_test.dart`.

The most common trigger is the **wide / split layout**. Mounting `SplitPane`
makes the subtree `watch(splitPaneRatioProvider)`, whose notifier hydrates from
persisted storage on build:

```
SplitPane                              ← mounted only in the wide layout
  └ watch(splitPaneRatioProvider)
      └ SplitPaneRatioNotifier._hydrate()
          └ ref.read(keyValueStoreProvider)   ← HiveStoreImpl, see lib/core/storage/hive_store.dart
              └ Hive.box('app_data')          ← throws if the box was never opened
```

Narrow-layout tests usually pass because they never mount `SplitPane`, so they
never touch the box. **That pass/fail asymmetry between narrow and wide layouts
is the tell-tale sign of a missing Hive setup**, not a real layout bug.

### Required Setup

Copied from the project convention (`test/widget_test.dart`,
`check_in_page_test.dart`, `request_logger_page_test.dart`):

```dart
import 'dart:io';
import 'package:hive_ce_flutter/hive_flutter.dart';

late Directory tempDir;

setUp(() async {
  // The wide layout mounts a SplitPane, which reads the Hive-backed
  // splitPaneRatioProvider. Initialize a throwaway Hive store so that read works.
  tempDir = await Directory.systemTemp.createTemp('hive_test_');
  Hive.init(tempDir.path);
  await Hive.openBox('app_data');
});

tearDown(() async {
  await Hive.close();
  await tempDir.delete(recursive: true);
});
```

> **Always pair `openBox` with the `tearDown` cleanup.** Leaving Hive open or
> leaking the temp directory bleeds state into the next test.

---

## Gotcha: `HiveError: Box not found` Masquerades as a Layout Crash

> **Warning**: When `app_data` is not opened, the resulting
> `HiveError: Box not found. Did you forget to call Hive.openBox()?` surfaces
> during `pumpAndSettle` as an unhandled async error wrapped in a giant
> `RenderProxyBoxMixin.performLayout` / `RenderObject.layout` stack trace.

**Symptom**: A wide-layout widget test fails with hundreds of `performLayout` /
`RenderObject.layout` frames that look exactly like a layout-overflow or
unbounded-constraint bug.

**Cause**: The Hive read throws *inside* the frame currently being laid out, so
the render pipeline is merely where the async error surfaced — it is **not** the
fault. Chasing the layout wastes time.

**Fix**: Search the failure trace for `HiveError` / `Box not found` before
touching any layout code. If present, add the Hive setup above.

**Prevention**: Initialize Hive in every test that mounts a persisted-state page
(anything reaching `SplitPane`, `splitPaneRatioProvider`, or
`keyValueStoreProvider`).

---

## Gotcha: `kDebugMode`-Defaulted Providers Are `true` Under `flutter test`

> **Warning**: `flutter test` runs in **debug mode**, so any provider defaulting
> to `kDebugMode` evaluates to `true`, never `false`.

**Example**: `requestLoggerEnabledProvider` is
`StateProvider<bool>((ref) => kDebugMode)`
(`lib/features/dev_tools/request_logger/presentation/providers/request_logger_providers.dart`).
A test that assumes the logger starts *off* instead renders the "ON / waiting"
state (`等待请求中...`) rather than the OFF empty state (`请求记录器尚未开启...`),
and a toggle test flips `true → false` instead of the intended `false → true`.

**Fix**: Pin the state explicitly before pumping, independent of `kDebugMode`:

```dart
// requestLoggerEnabledProvider defaults to kDebugMode (true under flutter test);
// pin it so the test starts from a known state.
container.read(requestLoggerEnabledProvider.notifier).state = false;
```

**Prevention**: Never assume a `kDebugMode`-defaulted provider's value in a test.
Set it to whatever your assertion actually requires.

---
