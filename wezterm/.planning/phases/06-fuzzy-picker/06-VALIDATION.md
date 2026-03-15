---
phase: 6
slug: fuzzy-picker
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-14
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual-only (GUI-driven phase) |
| **Config file** | None |
| **Quick run command** | `wezterm show-config` (syntax check only) |
| **Full suite command** | Interactive testing per Task 3 checkpoint |
| **Estimated runtime** | ~1 second (syntax check) + ~60 seconds (interactive) |

---

## Sampling Rate

- **After every task commit:** Run `wezterm show-config` inline (syntax check, < 1s)
- **After all auto tasks complete:** Interactive checkpoint (Task 3) covers full behavior
- **Before `/gsd:verify-work`:** Full interactive testing of all behaviors
- **Max feedback latency:** 1 second (syntax check)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Verification | Status |
|---------|------|------|-------------|-----------|--------------|--------|
| 06-01-01 | 01 | 1 | REQ-05 | manual + inline syntax check | Executor runs `wezterm show-config` + confirms file contents | pending |
| 06-01-02 | 01 | 1 | REQ-05 | manual + inline syntax check | Executor runs `wezterm show-config` + greps for keybinding/hint | pending |
| 06-01-03 | 01 | 1 | REQ-05 | manual (checkpoint) | Human interactive testing of 12-step verification | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

None -- this phase is GUI-driven. All verification is either inline syntax checks (`wezterm show-config`) performed by the executor during task execution, or interactive human testing in the checkpoint task. No separate test script needed.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Picker opens on CMD+CTRL+S | REQ-05 | Requires GUI interaction | Press CMD+CTRL+S in WezTerm, verify picker appears with title "Sessions" |
| Picker shows all sessions | REQ-05 | Requires visual inspection | Create 2+ sessions, open picker, verify all names appear |
| Selection switches to session | REQ-05 | Requires workspace state | Select non-current session, verify workspace changes |
| Current session marked with `*` | REQ-05 | Visual verification | Open picker, verify current session has `* ` prefix |
| Escape dismisses picker | REQ-05 | Keyboard interaction | Press Escape while picker is open, verify it closes |
| Empty list shows message | REQ-05 | Requires fresh state | Delete all sessions, open picker, verify message appears |
| Error toast on failed attach | REQ-05 | Requires error condition | Corrupt a session JSON, select it, verify toast notification |

---

## Validation Sign-Off

- [x] Manual-only phase: no `<automated>` tags, inline syntax checks only
- [x] Sampling continuity: syntax check after each task, full interactive checkpoint at end
- [x] No Wave 0 needed (GUI-driven, manual-only)
- [x] No watch-mode flags
- [x] Feedback latency < 2s (syntax check is < 1s)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved (manual-only is valid per Nyquist framework for GUI-driven phases)
