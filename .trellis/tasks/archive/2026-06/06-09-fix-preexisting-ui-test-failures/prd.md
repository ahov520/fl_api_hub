# 修复 check_in 与 request_logger 预存测试失败

## Goal

修复 baseline 中已存在的 widget 测试失败（与余额计算无关），从
`06-09-fix-balance-double-deduction` 任务中分离出来独立跟踪。

## Confirmed Facts（已确认，2026-06-09）

- 通过 `git stash` baseline 诊断：在 `fix-balance-double-deduction` 改动**之前**，
  原始代码就有 **9 个测试失败**（`-9: Some tests failed`），与余额修复无因果关系。
- 失败文件：
  - `test/features/check_in/presentation/pages/check_in_page_test.dart`
  - `test/features/dev_tools/request_logger/request_logger_page_test.dart`
- 典型失败：`Expected: exactly one matching candidate` /
  `Found 0 widgets with text containing 请求记录器尚未开启` —— widget finder 找不到
  唯一匹配，疑似页面文案/结构与测试期望不一致，或测试环境（本地化/字体）问题。
- 另有 1 个 pre-existing analyze warning：`_buildAuxBar` 未引用
  （`lib/features/accounts/presentation/pages/account_edit_page.dart:238`）。

## Requirements

- 逐一排查两个测试文件的失败根因（文案变更？finder 选择器过期？widget 树结构变化？）。
- 修复使 `flutter test` 全量通过。
- 顺带评估是否清理 `_buildAuxBar` 未引用告警。

## Acceptance Criteria

- [ ] `flutter test` 全量通过（0 失败）。
- [ ] `flutter analyze` 0 warning（含 `_buildAuxBar`）。

## Out of Scope

- 不改动余额计算逻辑（已由 06-09-fix-balance-double-deduction 完成）。

## Notes

- 优先级 P2（不阻塞余额修复）。诊断证据来源：fix-balance-double-deduction 的 baseline 测试。
