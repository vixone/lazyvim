---
phase: 5
slug: layout-restoration
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-03-14
---

# Phase 5 -- Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash test suite (bin/test-phase5.sh) |
| **Config file** | none -- Wave 0 creates test runner |
| **Quick run command** | `bin/test-phase5.sh` |
| **Full suite command** | `bin/test-phase5.sh --verbose` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bin/test-phase5.sh`
- **After every plan wave:** Run `bin/test-phase5.sh --verbose`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

### Plan 05-01: Restore module (Wave 0 + Wave 1)

| Task ID | Wave | Requirement | Test Name | Test Type | Automated Command | Status |
|---------|------|-------------|-----------|-----------|-------------------|--------|
| 05-01-T1 | 0 | gate | test_config_syntax | structural | `bin/test-phase5.sh test_config_syntax` | pending |
| 05-01-T1 | 0 | REQ-03 | test_sample_session_json | structural | `bin/test-phase5.sh test_sample_session_json` | pending |
| 05-01-T2 | 1 | REQ-03 | test_restore_functions_exist | grep | `bin/test-phase5.sh test_restore_functions_exist` | pending |
| 05-01-T2 | 1 | REQ-04 | test_restorable_processes_defined | grep | `bin/test-phase5.sh test_restorable_processes_defined` | pending |
| 05-01-T2 | 1 | REQ-03 | test_split_direction_logic | grep | `bin/test-phase5.sh test_split_direction_logic` | pending |
| 05-01-T2 | 1 | REQ-03 | test_first_pane_reuse | grep | `bin/test-phase5.sh test_first_pane_reuse` | pending |
| 05-01-T2 | 1 | REQ-04 | test_nil_safe_process | grep | `bin/test-phase5.sh test_nil_safe_process` | pending |
| 05-01-T2 | 1 | ATTACH | test_attach_smart_behavior | grep | `bin/test-phase5.sh test_attach_smart_behavior` | pending |
| 05-01-T2 | 1 | REQ-03 | test_missing_cwd_fallback | grep | `bin/test-phase5.sh test_missing_cwd_fallback` | pending |
| 05-01-T2 | 1 | REQ-03 | test_tab_title_restore | grep | `bin/test-phase5.sh test_tab_title_restore` | pending |

### Plan 05-02: CLI attach (Wave 2)

| Task ID | Wave | Requirement | Test Name | Test Type | Automated Command | Status |
|---------|------|-------------|-----------|-----------|-------------------|--------|
| 05-02-T1 | 2 | REQ-03 | test_cli_attach_function | grep | `bin/test-phase5.sh test_cli_attach_function` | pending |
| 05-02-T1 | 2 | REQ-03 | test_cli_attach_routing | grep | `bin/test-phase5.sh test_cli_attach_routing` | pending |
| 05-02-T1 | 2 | REQ-03 | test_cli_help_includes_attach | functional | `bin/test-phase5.sh test_cli_help_includes_attach` | pending |
| 05-02-T1 | 2 | REQ-03 | test_cli_attach_missing_name | functional | `bin/test-phase5.sh test_cli_attach_missing_name` | pending |

### Plan 05-02: Checkpoint (Wave 2)

| Task ID | Wave | Requirement | Verification | Type | Status |
|---------|------|-------------|--------------|------|--------|
| 05-02-T2 | 2 | REQ-03/04 | All 14 tests pass | automated pre-check | pending |
| 05-02-T2 | 2 | REQ-03 | Running session attach switches workspace | manual | pending |
| 05-02-T2 | 2 | REQ-03/04 | Saved session restores tabs/panes/CWDs/processes | manual | pending |
| 05-02-T2 | 2 | REQ-03 | Non-existent session shows error | manual | pending |
| 05-02-T2 | 2 | REQ-03 | Help text includes attach | manual | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

Wave 0 is Plan 05-01 Task 1. It creates:

- [x] `bin/test-phase5.sh` -- test runner with 10 test functions covering REQ-03, REQ-04, ATTACH behaviors
- [x] `sessions/test-restore.json` -- sample session JSON with 2 tabs, 4 panes for validation
- [x] Skip-on-missing pattern -- tests 2-10 return SKIP (exit 2) when manager.lua restore functions don't exist yet

**Wave 0 exit criteria:** `bin/test-phase5.sh` runs successfully. test_config_syntax and test_sample_session_json PASS. All other 8 tests SKIP. After Wave 0 completes, set `wave_0_complete: true` in this file's frontmatter.

**Wave 1 transition:** After Plan 05-01 Task 2 implements manager.lua restore functions, all 10 tests transition from SKIP to PASS. This validates that implementation satisfies the contracts established in Wave 0.

---

## Checkpoint Validation Chain (05-02 Task 2)

The human-verify checkpoint in Plan 05-02 relies on a two-layer validation:

1. **Automated layer (pre-check):** `bash bin/test-phase5.sh --verbose` -- all 14 tests must PASS. This covers:
   - Lua restore API structure (tests 2-6, 8-10 from 05-01)
   - CLI attach plumbing (tests 11-14 from 05-02)
   - Test JSON validity (test 7)
   - Config syntax gate (test 1)

2. **Manual layer (human judgment):** Visual and interactive verification of behaviors that cannot be tested via grep/structural checks:
   - Does attach to a running session actually switch workspaces (not just pass a grep)?
   - Does restored session have visually correct pane layout?
   - Are processes actually running in the correct panes?
   - Is workspace isolation preserved (existing work unaffected)?

The manual tests in VALIDATION.md "Manual-Only Verifications" section are verified during this checkpoint.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Visual layout matches saved positions | REQ-03 | Geometry accuracy requires visual inspection | Save 2-tab, 3-pane session. Restore. Visually compare pane layout. |
| Process running in correct pane | REQ-04 | Process state requires interactive verification | Restore session with nvim+shell. Verify nvim is running in correct pane. |
| Workspace isolation during restore | REQ-03 | Requires observing existing tabs unaffected | Have active work in tabs. Restore session. Verify active tabs unchanged. |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (tests skip until implementation exists)
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [x] Checkpoint validation chain documented (05-02 Task 2)
- [x] Test names in Per-Task Verification Map match test names in plan actions
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** ready
