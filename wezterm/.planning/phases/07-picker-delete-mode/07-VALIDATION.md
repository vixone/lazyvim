---
phase: 7
slug: picker-delete-mode
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-14
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual testing + shell script validation (WezTerm GUI) |
| **Config file** | none — Wave 0 creates `bin/test-phase7.sh` |
| **Quick run command** | `wezterm show-config 2>&1; echo "exit:$?"` |
| **Full suite command** | `bash bin/test-phase7.sh --verbose` |
| **Estimated runtime** | ~2 seconds (syntax) / ~60 seconds (manual) |

---

## Sampling Rate

- **After every task commit:** Run `wezterm show-config 2>&1; echo "exit:$?"`
- **After every plan wave:** Run `bash bin/test-phase7.sh --verbose` + manual interactive test
- **Before `/gsd:verify-work`:** Full manual test checklist must be green
- **Max feedback latency:** 2 seconds (automated) / 60 seconds (manual)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 07-01-01 | 01 | 1 | REQ-06 | syntax | `wezterm show-config` | ✅ | ⬜ pending |
| 07-01-02 | 01 | 1 | REQ-06 | manual | Interactive: enter delete mode, verify title/icons | ❌ W0 | ⬜ pending |
| 07-01-03 | 01 | 1 | REQ-06 | manual | Interactive: confirm deletion, verify picker reopens | ❌ W0 | ⬜ pending |
| 07-01-04 | 01 | 1 | REQ-06 | manual | Interactive: cancel deletion, verify delete mode stays | ❌ W0 | ⬜ pending |
| 07-01-05 | 01 | 1 | REQ-06 | manual | Interactive: delete all non-current, verify auto-close | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `bin/test-phase7.sh` — syntax validation for extended picker.lua
  - Check: `wezterm show-config` exits 0
  - Check: Lua file loads without error
- [ ] Manual test checklist embedded in PLAN.md verification section

*Existing infrastructure partially covers: `wezterm show-config` already validates Lua config.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Delete mode sentinel appears in switch mode | REQ-06 | GUI interaction required | Open picker (CMD+CTRL+S), verify "🗑 Delete mode..." appears at bottom |
| Delete mode title shows "Sessions [DELETE]" | REQ-06 | Visual verification | Select delete mode sentinel, verify title changes |
| Trash icon prefix on deletable sessions | REQ-06 | Visual verification | In delete mode, verify "🗑 " prefix on non-current sessions |
| Current session shows "(current)" label | REQ-06 | Visual verification | In delete mode, verify current session has "(current)" without trash icon |
| PromptInputLine confirmation prompt | REQ-06 | GUI text input required | Select deletable session, verify prompt text |
| Case-insensitive "y"/"yes" confirmation | REQ-06 | GUI text input required | Type "y", "Y", "yes", "YES" — all should confirm |
| Cancel on non-matching input | REQ-06 | GUI text input required | Type "", "no", "n" — should cancel, reopen in delete mode |
| Post-deletion picker reopens in switch mode | REQ-06 | State transition verification | Confirm deletion, verify picker reopens showing "Sessions" title |
| Post-cancel picker reopens in delete mode | REQ-06 | State transition verification | Cancel deletion, verify picker reopens showing "Sessions [DELETE]" |
| Auto-close when no deletable sessions remain | REQ-06 | Scenario testing | Delete all non-current sessions, verify picker doesn't reopen |
| "← Back to sessions..." returns to switch mode | REQ-06 | GUI interaction | Select back sentinel, verify title changes to "Sessions" |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 60s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
