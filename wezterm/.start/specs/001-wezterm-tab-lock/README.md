# Specification: 001-wezterm-tab-lock

## Status

| Field | Value |
|-------|-------|
| **Created** | 2026-03-11 |
| **Current Phase** | Ready |
| **Last Updated** | 2026-03-11 |

## Documents

| Document | Status | Notes |
|----------|--------|-------|
| requirements.md | completed | 3 Must Have + 1 Should Have features, 10 acceptance criteria |
| solution.md | completed | 5 ADRs confirmed, implementation examples for all components |
| plan/ | completed | 1 phase, 5 tasks (2 parallel), full PRD/SDD traceability |

**Status values**: `pending` | `in_progress` | `completed` | `skipped`

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-03-11 | Created spec 001-wezterm-tab-lock | User wants tab lock feature to prevent accidental CMD+W tab closure |
| 2026-03-11 | PRD completed | All requirements defined. Approach: wezterm.GLOBAL state, silent block + toast, lock icon in tab title. Standard mode (no agent team). |
| 2026-03-11 | Chose CMD+SHIFT+L as toggle | No conflict with existing keybindings. CMD+SHIFT already used for other features (N, M, T, V). |
| 2026-03-11 | Chose silent block + toast over confirmation dialog | User prefers non-intrusive feedback. Confirmation requires nightly WezTerm. |
| 2026-03-11 | Chose wezterm.GLOBAL over user vars or file | Simplest approach, no shell integration needed, survives config reloads |
| 2026-03-11 | SDD completed | 5 ADRs (all confirmed). String return for format-tab-title (preserves theme colors). 3 helper functions: is_tab_locked, toggle_tab_lock, guarded_close. |
| 2026-03-11 | PLAN completed | Single phase, 5 tasks. T1.3 and T1.4 can run in parallel. Full E2E validation as T1.5. |
| 2026-03-11 | Specification READY | All 3 documents complete. Ready for implementation via /start:implement. |

## Context

WezTerm tab lock feature — prevent accidentally closing tabs with CMD+W. The tab lock should make it harder to close important tabs, requiring an explicit unlock or confirmation step.

---
*This file is managed by the specify-meta skill.*
