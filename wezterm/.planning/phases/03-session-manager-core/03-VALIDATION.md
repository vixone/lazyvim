---
phase: 3
slug: session-manager-core
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-14
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual testing + shell validation script |
| **Config file** | none — Wave 0 installs |
| **Quick run command** | `wezterm --help > /dev/null 2>&1` |
| **Full suite command** | `bash bin/test-phase3.sh --verbose` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `wezterm --help > /dev/null 2>&1`
- **After every plan wave:** Run `bash bin/test-phase3.sh --verbose`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 0 | REQ-02 | unit | `grep -q "function M.create_session" lua/session/manager.lua` | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 0 | REQ-02 | unit | `grep -q "function M.list_sessions" lua/session/manager.lua` | ❌ W0 | ⬜ pending |
| 03-01-03 | 01 | 0 | REQ-02 | unit | `grep -q "function M.switch_session" lua/session/manager.lua` | ❌ W0 | ⬜ pending |
| 03-01-04 | 01 | 0 | REQ-02 | unit | `grep -q "function M.delete_session" lua/session/manager.lua` | ❌ W0 | ⬜ pending |
| 03-02-01 | 02 | 1 | REQ-02 | integration | `bash bin/test-phase3.sh` | ❌ W0 | ⬜ pending |
| 03-02-02 | 02 | 1 | REQ-02 | integration | `bash bin/test-phase3.sh` | ❌ W0 | ⬜ pending |
| 03-02-03 | 02 | 1 | REQ-02 | integration | `bash bin/test-phase3.sh` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `bin/test-phase3.sh` — shell script to validate manager.lua functions exist, name validation works, default protection works
- [ ] `lua/session/manager.lua` — core module stubs (created in Wave 1, validated by Wave 0 script)

*Wave 0 creates test infrastructure; Wave 1 creates the module.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Idempotent create | REQ-02 | Requires live WezTerm mux to verify workspace dedup | Create session "test" twice, verify no error and single workspace |
| Active session deletion | REQ-02 | Requires live workspace switching observation | Delete active session, verify auto-switch to another session |
| Default workspace protection | REQ-02 | Requires live mux to verify "default" cannot be deleted | Attempt `delete_session("default")`, verify rejection |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
