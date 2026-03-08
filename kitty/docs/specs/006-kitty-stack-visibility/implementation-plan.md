---
title: "Stack Window Count in Tab Title"
status: complete
version: "1.0"
---

# Implementation Plan

## Validation Checklist

### CRITICAL GATES (Must Pass)

- [x] All `[NEEDS CLARIFICATION]` markers addressed
- [x] All specification file paths correct and exist
- [x] Each phase follows TDD: Prime → Test → Implement → Validate
- [x] Every task has verifiable success criteria
- [x] A developer could follow this plan independently

### QUALITY CHECKS (Should Pass)

- [x] Context priming section complete
- [x] All implementation phases defined
- [x] Dependencies between phases clear (no circular dependencies)
- [x] Parallel work tagged with `[parallel: true]`
- [x] Activity hints provided for specialist selection
- [x] Every phase references relevant SDD sections
- [x] Every test references SDD acceptance criteria
- [x] E2E tests defined in final phase
- [x] Project commands match actual project setup

---

## Context Priming

*GATE: Read all files in this section before starting any implementation.*

**Specification**:
- `docs/specs/006-kitty-stack-visibility/solution-design.md` — Solution Design (primary reference)

**Key Design Decisions**:
- **ADR-10**: `⊞N` suffix — append `(' ⊞' + str(num_windows)) if layout_name == 'stack' and num_windows > 1 else ''` to both tab title templates
- **Condition logic**: `num_windows > 1` suppresses indicator when only 1 window in tab (nothing hidden)
- **Both templates**: `tab_title_template` (inactive tabs) AND `active_tab_title_template` (active tab) both get the suffix

**Implementation Context**:
```bash
# Reload config (no restart needed)
Reload: Ctrl+Shift+F5  (inside Kitty)

# Verify no parse errors
Debug: kitty --debug-config

# Manual E2E verification (see Phase 2)
Test: create panes, toggle stack, observe tab bar
```

---

## Implementation Phases

Each task follows red-green-refactor: **Prime** (understand context), **Test** (red), **Implement** (green), **Validate** (refactor + verify).

---

### Phase 1: Config Patch

Single edit to `kitty.conf` — modify both tab title templates.

- [x] **T1.1 Update `tab_title_template` and `active_tab_title_template`** `[activity: config]`

  1. Prime: Read `kitty.conf` lines 16-17; read `docs/specs/006-kitty-stack-visibility/solution-design.md` → Interface Specifications / Template Before / After `[ref: SDD/Interface Specifications]`
  2. Test: Confirm current lines 16-17 are:
     ```
     tab_title_template       "{tab.active_wd.rsplit('/', 1)[-1]}"
     active_tab_title_template "{(session_name + ' › ') if session_name else ''}{tab.active_wd.rsplit('/', 1)[-1]}"
     ```
  3. Implement: Replace lines 16-17 in `~/.config/kitty/kitty.conf` with:
     ```
     tab_title_template       "{tab.active_wd.rsplit('/', 1)[-1]}{(' ⊞' + str(num_windows)) if layout_name == 'stack' and num_windows > 1 else ''}"
     active_tab_title_template "{(session_name + ' › ') if session_name else ''}{tab.active_wd.rsplit('/', 1)[-1]}{(' ⊞' + str(num_windows)) if layout_name == 'stack' and num_windows > 1 else ''}"
     ```
  4. Validate: Reload with `Ctrl+Shift+F5` — no error dialog; `kitty --debug-config` shows no parse errors
  5. Success:
     - [ ] Both template lines updated `[ref: SDD/Interface Specifications]`
     - [ ] Config reloads cleanly with no parse errors `[ref: SDD/Deployment View]`

---

### Phase 2: E2E Verification

Manual end-to-end testing. No code changes — verification only.

- [ ] **T2.1 Stack indicator shows and hides correctly** `[activity: e2e-test]`

  1. Reload config: `Ctrl+Shift+F5`
  2. Create 3 panes: `Cmd+D` twice
  3. Verify tab title in tall layout: shows `proj` (no indicator)
  4. Enter stack: `Cmd+Shift+F` → tab title must show `proj ⊞3`
  5. Exit stack: `Cmd+Shift+F` → tab title must return to `proj`
  6. Close 2 panes to leave 1: enter stack (`Cmd+Shift+F`) → tab title must show `proj` (no `⊞1` — suppressed)

  Success criteria:
  - [ ] `⊞3` appears in tab title when stack layout has 3 windows `[ref: SDD/Acceptance Criteria]`
  - [ ] Indicator disappears when switching to non-stack layout `[ref: SDD/Acceptance Criteria]`
  - [ ] `⊞1` is NOT shown when only 1 window in stack `[ref: SDD/Acceptance Criteria]`

- [ ] **T2.2 Session prefix preserved** `[activity: e2e-test]`

  1. With a session active (check `which_key.py` session workflow)
  2. Enter stack with 2 panes: title must show `session › proj ⊞2`
  3. Without session: title must show `proj ⊞2`

  Success criteria:
  - [ ] Session prefix `session › ` preserved in active tab when session set `[ref: SDD/Constraints CON-3]`
  - [ ] Inactive tabs show `proj ⊞N` without session prefix (expected — session prefix only in active template)

- [ ] **T2.3 Regression — non-stack tabs unaffected** `[activity: e2e-test]`

  1. With multiple panes, stay in tall layout
  2. Verify tab bar shows `proj` with no suffix
  3. Open multiple tabs, switch between them — verify none show `⊞` indicator in tall/fat/grid

  Success criteria:
  - [ ] No indicator in tall, fat, or grid layouts `[ref: SDD/Constraints CON-4]`
  - [ ] All spec 001/002 tab behaviors unchanged

---

## Plan Verification

| Criterion | Status |
|-----------|--------|
| A developer can follow this plan without additional clarification | ✅ |
| Every task produces a verifiable deliverable | ✅ |
| All SDD acceptance criteria map to specific tasks | ✅ |
| All SDD components have implementation tasks | ✅ |
| Dependencies are explicit with no circular references | ✅ |
| Parallel opportunities marked with `[parallel: true]` | ✅ (T2.1 ∥ T2.2 ∥ T2.3 in Phase 2) |
| Each task has specification references `[ref: ...]` | ✅ |
| Project commands in Context Priming are accurate | ✅ |

## Dependency Graph

```
T1.1 (config patch) → T2.1 ∥ T2.2 ∥ T2.3 (E2E, parallel)
```

## Task Summary

| Phase | Tasks | Parallel | Files Touched |
|-------|-------|----------|---------------|
| 1 — Config Patch | T1.1 | — | `kitty.conf` (lines 16-17) |
| 2 — E2E | T2.1, T2.2, T2.3 | T2.1 ∥ T2.2 ∥ T2.3 | None (verification only) |
| **Total** | **4 tasks** | **3 parallel** | **1 file** |
