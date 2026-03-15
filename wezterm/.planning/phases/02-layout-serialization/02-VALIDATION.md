---
phase: 2
slug: layout-serialization
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-14
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual testing + shell validation script |
| **Config file** | None — validation script in `bin/test-phase2.sh` |
| **Quick run command** | `wezterm --help > /dev/null 2>&1` |
| **Full suite command** | `bash bin/test-phase2.sh --verbose` |
| **Estimated runtime** | ~5 seconds |

*Note: `wezterm show-config` does not exist. Phase 1 confirmed that `wezterm --help` is the correct syntax validation command.*

---

## Sampling Rate

- **After every task commit:** Run `wezterm --help > /dev/null 2>&1`
- **After every plan wave:** Run `bash bin/test-phase2.sh --verbose`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-00-01 | 00 | 0 | REQ-09 | unit | `bash bin/test-phase2.sh --verbose` | Created by this task | ⬜ pending |
| 02-01-01 | 01 | 1 | REQ-09 | unit | `wezterm --help > /dev/null 2>&1` | ✅ | ⬜ pending |
| 02-01-02 | 01 | 1 | REQ-09 | integration | `bash bin/test-phase2.sh` | ✅ W0 | ⬜ pending |
| 02-02-01 | 02 | 2 | REQ-09 | integration | `wezterm --help > /dev/null 2>&1 && bash bin/test-phase2.sh` | ✅ W0 | ⬜ pending |
| 02-02-02 | 02 | 2 | REQ-09 | manual | `(manual) Open/close tab, verify JSON updated` | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `bin/test-phase2.sh` — Shell script to validate module structure, config syntax, JSON output (created by 02-00-PLAN.md)
- [x] Manual test checklist — REQ-09 feature verification steps embedded in 02-02-PLAN.md checkpoint task

*Note: WezTerm Lua configs don't have traditional unit test frameworks. Testing uses `wezterm --help` for syntax validation and shell scripts for integration verification.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Auto-save triggers on workspace changes | REQ-09 | Requires interactive tab/pane operations | 1. Open tab 2. Check sessions/ for JSON 3. Close tab 4. Verify JSON updated |
| JSON is human-readable and git-diffable | REQ-09 | Requires human judgment on readability | 1. Read sessions/default.json 2. Verify clean structure 3. Make change, diff with git |
| One file per workspace | REQ-09 | Requires creating multiple workspaces | 1. Create workspace 2. Check sessions/ has new file 3. Verify no cross-contamination |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 5s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved
