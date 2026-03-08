---
title: "Quick-Access Terminal (Frosted) + Stacked Pane Navigation"
status: draft
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
- [x] Every test references PRD acceptance criteria
- [x] E2E tests defined in final phase
- [x] Project commands match actual project setup

---

## Context Priming

*GATE: Read all files in this section before starting any implementation.*

**Specification**:
- `docs/specs/002-overlay-and-stacked-panes/product-requirements.md` — Product Requirements
- `docs/specs/002-overlay-and-stacked-panes/solution-design.md` — Solution Design (primary reference)

**Key Design Decisions**:
- **ADR-6**: `kitten quick_access_terminal` replaces `launch --type=overlay` — native toggle + frosted `background_opacity 0.85`
- **ADR-7**: `Opt+H/J/K/L` → `neighboring_window` directions — vim-style spatial aliases, no-op in stack
- **ADR-8**: `Cmd+;` → `focus_visible_window` — visual pane picker, works in all layouts
- **ADR-9**: `Opt+9` / `Opt+0` → `previous_window` / `next_window` — split-keyboard friendly stack cycling

**Implementation Context**:
```bash
# Reload config (no restart needed)
Reload: Ctrl+Shift+F5  (inside Kitty)

# Verify no parse errors
Debug: kitty --debug-config

# Manual E2E verification (see Phase 3)
Test: press each new keybinding and observe behavior
```

---

## Implementation Phases

Each task follows red-green-refactor: **Prime** (understand context), **Test** (red — define expected behavior), **Implement** (green), **Validate** (verify correctness).

---

### Phase 1: Foundation — opacity support + scratchpad config

Enables `background_opacity` to work at runtime and creates the scratchpad appearance config. Both tasks are independent and can be done in any order.

- [ ] **T1.1 Add `dynamic_background_opacity yes` to kitty.conf** `[activity: config]`

  1. Prime: Read `solution-design.md` — Implementation Gotchas section; `kitty.conf` current state `[ref: SDD/Implementation Gotchas]`
  2. Test: Open `kitty.conf` — confirm `dynamic_background_opacity` is NOT present; after adding, reload with `Ctrl+Shift+F5` — no error
  3. Implement: Add `dynamic_background_opacity yes` to `~/.config/kitty/kitty.conf` in the Advanced section
  4. Validate: Reload with `Ctrl+Shift+F5`; no error dialog; `kitty --debug-config` shows no parse errors
  5. Success: `dynamic_background_opacity yes` present in `kitty.conf`; config reloads cleanly `[ref: SDD/Deployment View]`

- [ ] **T1.2 Create `quick-access-terminal.conf`** `[activity: config]` `[parallel: true]`

  1. Prime: Read `solution-design.md` — Interface Specifications / quick-access-terminal.conf section `[ref: SDD/Interface Specifications]`
  2. Test: File does not exist yet at `~/.config/kitty/quick-access-terminal.conf`
  3. Implement: Create `~/.config/kitty/quick-access-terminal.conf` with:
     ```
     edge top
     lines 15
     background_opacity 0.85
     hide_on_focus_loss yes
     kitty_override background=#1e1f2e
     ```
  4. Validate: File exists at correct path; no syntax errors (YAML-like conf format)
  5. Success:
     - [ ] File exists at `~/.config/kitty/quick-access-terminal.conf` `[ref: SDD/Directory Map]`
     - [ ] Contains `edge top`, `background_opacity 0.85`, `hide_on_focus_loss yes` `[ref: SDD/Interface Specifications]`

---

### Phase 2: Keybindings update

Replaces the old overlay binding and adds all 7 new keybindings. Single file edit with no dependencies between individual lines.

- [ ] **T2.1 Replace `cmd+f` overlay binding with `kitten quick_access_terminal`** `[activity: config]`

  1. Prime: Read `keybindings.conf` line 37 (current `cmd+f` binding); read SDD ADR-6 `[ref: SDD/ADR-6]`
  2. Test: Current binding is `map cmd+f launch --type=overlay --title=overlay zsh` — this must be replaced
  3. Implement: In `~/.config/kitty/keybindings.conf`, replace:
     - `map cmd+f          launch --type=overlay --title=overlay zsh`
     with:
     - `map cmd+f          kitten quick_access_terminal`
     Update section comment from `# ─── OVERLAY / FLOATING PANE (ADR-4)` to `# ─── SCRATCHPAD / QUICK-ACCESS (ADR-6)`
  4. Validate: Old `launch --type=overlay` line no longer present; `kitten quick_access_terminal` present
  5. Success: `Cmd+F` no longer opens a plain overlay; opens frosted scratchpad window `[ref: PRD/Feature 1 AC]`

- [ ] **T2.2 Add vim spatial navigation bindings (Opt+HJKL)** `[activity: config]`

  1. Prime: Read SDD ADR-7; confirm `opt+h/j/k/l` are free in current `keybindings.conf` `[ref: SDD/Keybinding Conflict Audit]`
  2. Test: No `opt+h`, `opt+j`, `opt+k`, `opt+l` bindings currently in `keybindings.conf`
  3. Implement: Add new section to `keybindings.conf` after the PANE NAVIGATION section:
     ```
     # ─── VIM-STYLE PANE NAVIGATION (ADR-7) ─────────────────────────────
     # Spatial aliases for Cmd+arrows. Silent no-op in stack layout (no neighbors).
     map opt+h           neighboring_window left
     map opt+j           neighboring_window down
     map opt+k           neighboring_window up
     map opt+l           neighboring_window right
     ```
  4. Validate: All 4 bindings present; reload config; no parse errors
  5. Success: `Opt+H/J/K/L` navigates between panes in tiled layouts `[ref: PRD/Feature 2 AC]`

- [ ] **T2.3 Add stack cycle bindings (Opt+9 / Opt+0)** `[activity: config]`

  1. Prime: Read SDD ADR-9; confirm `opt+9` and `opt+0` are free `[ref: SDD/Keybinding Conflict Audit]`
  2. Test: No `opt+9` or `opt+0` bindings in `keybindings.conf`; `cmd+9` = goto_tab 9 (different modifier — no conflict)
  3. Implement: Add new section to `keybindings.conf`:
     ```
     # ─── STACK CYCLE NAVIGATION (ADR-9) ────────────────────────────────
     # Cycles through all windows in tab. Works in stack layout where opt+hjkl no-ops.
     map opt+9           previous_window
     map opt+0           next_window
     ```
  4. Validate: Both bindings present; reload config; no parse errors
  5. Success: `Opt+0` cycles to next pane in stack layout; `Opt+9` cycles to previous `[ref: PRD/Feature 2 AC]`

- [ ] **T2.4 Add visual pane picker binding (Cmd+;)** `[activity: config]`

  1. Prime: Read SDD ADR-8; confirm `cmd+;` is free `[ref: SDD/Keybinding Conflict Audit]`
  2. Test: No `cmd+;` binding in `keybindings.conf`
  3. Implement: Add to `keybindings.conf` in or near SCROLLBACK & HINTS section:
     ```
     # ─── VISUAL PANE PICKER (ADR-8) ────────────────────────────────────
     map cmd+;           focus_visible_window
     ```
  4. Validate: Binding present; reload config; no parse errors
  5. Success: `Cmd+;` shows numbered pane overlays; pressing a number focuses that pane `[ref: PRD/Feature 3 AC]`

- [ ] **T2.5 Update `KEYBINDINGS.md` reference table** `[activity: docs]`

  1. Prime: Read `KEYBINDINGS.md` current content — identify sections to update
  2. Test: `KEYBINDINGS.md` still references old overlay behavior; missing new bindings
  3. Implement: Update `KEYBINDINGS.md`:
     - Replace overlay row: `Cmd+F` → "Open quick-access scratchpad (frosted toggle)"
     - Add Vim Navigation section with `Opt+H/J/K/L` table
     - Add Stack Cycle section with `Opt+9` / `Opt+0` table
     - Add Visual Picker row: `Cmd+;` → `focus_visible_window`
     - Add ADR-7 note (vim spatial no-ops in stack; use Opt+9/0 for stack cycling)
  4. Validate: All new bindings documented; no references to old `launch --type=overlay`
  5. Success: `KEYBINDINGS.md` is accurate and complete `[ref: SDD/Directory Map]`

---

### Phase 3: E2E Verification

Manual end-to-end testing of all new behaviors. No code changes — verification only.

- [ ] **T3.1 Scratchpad toggle E2E** `[activity: e2e-test]`

  1. Reload config: `Ctrl+Shift+F5`
  2. Test scratchpad show: `Cmd+F` → frosted window appears anchored to top of screen
  3. Verify visual: Background is noticeably different from regular panes (semi-transparent / `#1e1f2e` tint)
  4. Run a command inside scratchpad: `cd /tmp && echo "hello"`
  5. Hide: `Cmd+F` → scratchpad hides, underlying panes visible
  6. Restore: `Cmd+F` → scratchpad reappears; `pwd` confirms `/tmp` (session preserved)
  7. Destroy: `Ctrl+D` → scratchpad closes; next `Cmd+F` starts fresh session (new `/tmp` not persisted)

  Success criteria:
  - [ ] Scratchpad is visually distinct (frosted / different bg) `[ref: PRD/Feature 1 AC-3]`
  - [ ] Session survives hide/show cycle `[ref: PRD/Feature 1 AC-2]`
  - [ ] `Ctrl+D` destroys session; next open is fresh `[ref: PRD/Feature 1 AC-4]`

- [ ] **T3.2 Vim navigation E2E** `[activity: e2e-test]`

  1. Create a vsplit: `Cmd+D`
  2. Navigate right: `Opt+L` → focus moves to right pane
  3. Navigate left: `Opt+H` → focus returns to left pane
  4. Create hsplit: `Cmd+Shift+D`
  5. Navigate down: `Opt+J` → focus moves to lower pane
  6. Navigate up: `Opt+K` → focus moves to upper pane
  7. In stack layout (`Cmd+Shift+F`): press `Opt+H` → silent no-op (expected)

  Success criteria:
  - [ ] `Opt+H/J/K/L` navigate between panes in tiled layouts `[ref: PRD/Feature 2 AC]`
  - [ ] No-op in stack layout confirmed `[ref: SDD/ADR-7 Trade-offs]`

- [ ] **T3.3 Stack cycle E2E** `[activity: e2e-test]`

  1. Create 3 panes (2× `Cmd+D`)
  2. Enter stack layout: `Cmd+Shift+F`
  3. Press `Opt+0` → next pane becomes visible
  4. Press `Opt+0` again → next pane
  5. Press `Opt+9` → previous pane
  6. Press `Opt+0` from last pane → wraps to first pane

  Success criteria:
  - [ ] `Opt+0` cycles forward through hidden panes in stack `[ref: PRD/Feature 2 AC]`
  - [ ] `Opt+9` cycles backward `[ref: PRD/Feature 2 AC]`
  - [ ] Wraps at boundaries `[ref: PRD/Feature 2 AC]`

- [ ] **T3.4 Visual picker E2E** `[activity: e2e-test]`

  1. With 3+ panes open, press `Cmd+;`
  2. Verify numbered overlays appear on each pane
  3. Press `1` → first pane focused
  4. Press `Cmd+;` again → press `Escape` → verify no state change

  Success criteria:
  - [ ] Numbered overlays appear on panes `[ref: PRD/Feature 3 AC]`
  - [ ] Number keypress jumps to correct pane `[ref: PRD/Feature 3 AC]`
  - [ ] Escape dismisses without change `[ref: PRD/Feature 3 AC]`

- [ ] **T3.5 Regression check — spec 001 bindings** `[activity: e2e-test]`

  Verify no spec 001 keybindings were broken:
  - `Cmd+D` → vsplit ✓
  - `Cmd+Shift+D` → hsplit ✓
  - `Cmd+W` → close pane ✓
  - `Cmd+arrows` → neighboring_window (still works alongside Opt+HJKL) ✓
  - `Cmd+Shift+[/]` → tab navigation ✓
  - `Cmd+L` → next_layout ✓
  - `Cmd+Shift+F` → toggle stack ✓
  - `Cmd+T` / `Cmd+1-9` → tab management ✓
  - `Cmd+E` → hints kitten ✓
  - `Cmd+Shift+H` → scrollback ✓

  Success: All spec 001 behaviors unchanged `[ref: SDD/Implementation Boundaries]`

---

## Plan Verification

| Criterion | Status |
|-----------|--------|
| A developer can follow this plan without additional clarification | ✅ |
| Every task produces a verifiable deliverable | ✅ |
| All PRD acceptance criteria map to specific tasks | ✅ |
| All SDD components have implementation tasks | ✅ |
| Dependencies are explicit with no circular references | ✅ |
| Parallel opportunities marked with `[parallel: true]` | ✅ (T1.1 + T1.2) |
| Each task has specification references `[ref: ...]` | ✅ |
| Project commands in Context Priming are accurate | ✅ |

## Dependency Graph

```
T1.1 (dynamic_background_opacity) ─┐
                                    ├─→ T2.1 → T2.2 → T2.3 → T2.4 → T2.5 → Phase 3
T1.2 (quick-access-terminal.conf) ─┘

T1.1 and T1.2 are parallel (independent)
T2.x tasks are sequential (same file, avoid conflicts)
T3.x tasks are parallel (independent E2E checks)
```

## Task Summary

| Phase | Tasks | Parallel | Files Touched |
|-------|-------|----------|---------------|
| 1 — Foundation | T1.1, T1.2 | T1.1 ∥ T1.2 | `kitty.conf`, `quick-access-terminal.conf` (NEW) |
| 2 — Keybindings | T2.1–T2.5 | Sequential | `keybindings.conf`, `KEYBINDINGS.md` |
| 3 — E2E | T3.1–T3.5 | T3.1 ∥ T3.2 ∥ T3.3 ∥ T3.4 ∥ T3.5 | None (verification only) |
| **Total** | **10 tasks** | **6 parallel** | **4 files** |
