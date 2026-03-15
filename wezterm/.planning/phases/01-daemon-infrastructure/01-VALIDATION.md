---
phase: 1
slug: daemon-infrastructure
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-14
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Manual testing + shell script validation |
| **Config file** | none — Wave 0 creates `bin/test-phase1.sh` |
| **Quick run command** | `wezterm show-config > /dev/null` |
| **Full suite command** | `bash bin/test-phase1.sh --verbose` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `wezterm show-config > /dev/null`
- **After every plan wave:** Run `bash bin/test-phase1.sh --verbose`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 0 | REQ-01 | smoke | `wezterm show-config > /dev/null` | ✅ | ⬜ pending |
| 01-01-02 | 01 | 1 | REQ-01 | integration | `bash bin/test-phase1.sh daemon_lifecycle` | ❌ W0 | ⬜ pending |
| 01-01-03 | 01 | 1 | REQ-01 | integration | `bash bin/test-phase1.sh persistence_check` | ❌ W0 | ⬜ pending |
| 01-02-01 | 02 | 1 | REQ-08 | smoke | `wezterm show-config \| grep -q 'unix_domains'` | ✅ | ⬜ pending |
| 01-02-02 | 02 | 1 | REQ-10 | manual | `(manual) CMD+SHIFT+T theme toggle` | ❌ W0 | ⬜ pending |
| 01-02-03 | 02 | 1 | REQ-10 | manual | `(manual) CMD+SHIFT+L tab lock` | ❌ W0 | ⬜ pending |
| 01-02-04 | 02 | 1 | REQ-10 | manual | `(manual) CTRL+hjkl smart-splits` | ❌ W0 | ⬜ pending |
| 01-02-05 | 02 | 1 | REQ-10 | manual | `(manual) Visual check hints bar` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `bin/test-phase1.sh` — automated daemon lifecycle and persistence tests
- [ ] Manual test checklist — REQ-10 feature regression (theme toggle, tab lock, smart-splits, hints bar)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Theme toggle works after changes | REQ-10 | Requires GUI interaction (CMD+SHIFT+T) | 1. Open WezTerm 2. Press CMD+SHIFT+T 3. Verify theme switches between dark/light |
| Tab lock works after changes | REQ-10 | Requires GUI interaction (CMD+SHIFT+L) | 1. Open WezTerm 2. Press CMD+SHIFT+L 3. Verify tab lock indicator appears in hints bar |
| Smart-splits navigation works | REQ-10 | Requires GUI + nvim pane navigation | 1. Open WezTerm with nvim 2. Create splits 3. CTRL+hjkl navigates between wezterm/nvim panes |
| Hints bar renders correctly | REQ-10 | Visual inspection required | 1. Open WezTerm 2. Check status bar shows Lock, Theme indicators 3. After Phase 1, verify mux indicator appears |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
