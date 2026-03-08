---
title: "Kitty Session UX — Implementation Plan"
status: draft
version: "1.0"
---

# Implementation Plan

## Validation Checklist

### CRITICAL GATES (Must Pass)

- [x] All `[NEEDS CLARIFICATION]` markers have been addressed
- [x] All specification file paths are correct and exist
- [x] Each phase follows TDD: Prime → Test → Implement → Validate
- [x] Every task has verifiable success criteria
- [x] A developer could follow this plan independently

### QUALITY CHECKS (Should Pass)

- [x] Context priming section is complete
- [x] All implementation phases are defined
- [x] Dependencies between phases are clear (no circular dependencies)
- [x] Parallel work properly tagged with `[parallel: true]`
- [x] Every phase references relevant SDD sections
- [x] Every test references PRD acceptance criteria
- [x] Integration & E2E tests defined in final phase

---

## Context Priming

*GATE: Read all files in this section before starting any implementation.*

**Specification**:
- `docs/specs/003-kitty-session-ux/product-requirements.md` — PRD, acceptance criteria
- `docs/specs/003-kitty-session-ux/solution-design.md` — SDD, ADRs, interface specs, wireframes

**Key Design Decisions**:
- **ADR-1**: Overlay captures input — `which_key.py` reads keypress via `tty.setraw`; no modal mapping used.
- **ADR-2**: Session name in tab titles — `tab_title_template` prefixes `session_name + ' › '` when non-empty.
- **ADR-3**: HINTS list in `which_key.py` — key→action mapping lives at top of the kitten file.
- **ADR-4**: Transient tab colour — `kitten @ set-tab-color` on overlay open/close; accent `#5e81ac`.

**Implementation Context**:
```bash
# Reload config (no restart needed)
ctrl+cmd+,    # or: kitten @ action load_config_file

# Verify kitten is valid Python before wiring
python3 ~/.config/kitty/which_key.py --check  # (manual syntax check)

# Check kitty remote control is working
kitten @ --to unix:/tmp/kitty ls | head -5

# Run the overlay manually for visual testing
kitten @ --to unix:/tmp/kitty launch --type=overlay python3 ~/.config/kitty/which_key.py
```

---

## Implementation Phases

Each task follows red-green-refactor: **Prime** (understand context), **Test** (red), **Implement** (green), **Validate** (refactor + verify).

---

### Phase 1: Config Changes

Delivers tab bar at top and session name in tab titles — two one-line config changes, verifiable immediately by visual inspection after reload.

- [ ] **T1.1 Move tab bar to top** `[activity: config]`

  1. Prime: Review `tab_bar_edge` option `[ref: SDD/Directory Map; kitty.conf]`
  2. Test: Reload kitty — tab bar currently at bottom (expected: top after change)
  3. Implement: Add `tab_bar_edge top` to `~/.config/kitty/kitty.conf` under the `# ─── DISPLAY ───` section
  4. Validate: Reload config (`ctrl+cmd+,`); open two tabs; confirm tab bar is at top
  5. Success: Tab bar displayed at top edge `[ref: PRD/Feature 1 AC]`; powerline style preserved `[ref: PRD/Feature 1 AC]`

- [ ] **T1.2 Session name prefix in tab titles** `[activity: config]`

  1. Prime: Review `tab_title_template` and `{session_name}` field `[ref: SDD/Example: tab_title_template with session name]`
  2. Test: Open a session file (e.g. `goto_session dotfiles`) — current tab title shows `1: zsh` with no session prefix
  3. Implement: Replace `tab_title_template` in `kitty.conf` with:
     `tab_title_template "{(session_name + ' › ') if session_name else ''}{index}: {title}"`
  4. Validate: Reload config; load a session; confirm tab titles show `<session> › N: <title>`; confirm non-session tabs show `N: <title>`
  5. Success:
     - [ ] Named session tabs show `session › N: title` `[ref: PRD/Feature 2 AC]`
     - [ ] Non-session tabs show `N: title` (no prefix) `[ref: PRD/Feature 2 AC]`
     - [ ] Switching sessions updates the prefix `[ref: PRD/Feature 2 AC]`

- [ ] **T1.3 Phase 1 Validation** `[activity: validate]`

  Verify both config lines are present and correct in `kitty.conf`. Reload and visually confirm tab bar position and session name prefix. No regressions in existing tab behaviour (powerline style, tab count, navigation).

---

### Phase 2: Which-Key Kitten

Delivers the `which_key.py` kitten and the `ctrl+o` binding that launches it. This is the core deliverable of the spec.

- [ ] **T2.1 Write `which_key.py` kitten** `[activity: scripting]`

  1. Prime: Read SDD kitten interface spec and implementation example `[ref: SDD/Interface Specifications; SDD/Example: which_key.py structure]`
  2. Test: Run `python3 ~/.config/kitty/which_key.py` in a terminal — should fail (file does not exist yet); creates the red baseline
  3. Implement: Create `~/.config/kitty/which_key.py` with:
     - `HINTS` list at top (3 entries: `w`, `l`, `s`) `[ref: SDD/Hint Table Data Model]`
     - `render_hints()` — clears screen, draws bordered box at bottom with key → label table `[ref: SDD/Hint Table Layout wireframe]`
     - `read_one_key()` — `tty.setraw` single keypress capture `[ref: SDD/Implementation Gotchas — tty.setraw]`
     - `set_tab_color(listen_on, color=None)` — calls `kitten @ set-tab-color` `[ref: ADR-4]`
     - `dispatch(listen_on, action_str)` — calls `kitten @ action` `[ref: SDD/kitten @ action interface]`
     - `main(args, answer)` — standard kitten entry point: set color → render → read → reset color → dispatch `[ref: SDD/Primary Flow sequence diagram]`
     - Save flow for key `s`: prompt for name, construct path, call `save_as_session` `[ref: SDD/Secondary Flow sequence diagram]`
     - Cancellation: Escape / unrecognised key → reset color → exit cleanly `[ref: SDD/Cancellation Flow]`
     - Exception guard: `try/finally` wrapping main logic to ensure `set_tab_color` reset always runs
  4. Validate:
     - `python3 -c "import which_key"` in `~/.config/kitty/` — no syntax errors
     - Launch manually via remote control: `kitten @ --to unix:/tmp/kitty launch --type=overlay python3 ~/.config/kitty/which_key.py`
     - Overlay appears; hint table renders; Escape closes cleanly; tab colour resets
  5. Success:
     - [ ] Overlay appears with hint table on `ctrl+o` `[ref: PRD/Feature 3 AC]`
     - [ ] Valid key executes action and closes overlay `[ref: PRD/Feature 3 AC]`
     - [ ] Escape closes overlay without action `[ref: PRD/Feature 3 AC]`
     - [ ] Active tab turns accent colour while overlay is open `[ref: PRD/Should Have — keyboard mode indicator]`
     - [ ] Tab colour resets on any exit path `[ref: SDD/Quality Requirements — Resilience]`

- [ ] **T2.2 Wire `ctrl+o` binding** `[activity: config]`

  1. Prime: Review current `ctrl+o` bindings in `keybindings.conf` `[ref: SDD/keybindings.conf MODIFY]`
  2. Test: Confirm current `ctrl+o>w`, `ctrl+o>l`, `ctrl+o>s` bindings are present (the old direct bindings)
  3. Implement: In `keybindings.conf`, replace the three `ctrl+o>*` lines in the `# ─── SESSIONS` block with a single binding:
     ```
     map ctrl+o launch --type=overlay python3 ~/.config/kitty/which_key.py
     ```
     Remove the old `ctrl+o>w`, `ctrl+o>l`, `ctrl+o>s` individual bindings (the kitten handles all three now)
  4. Validate: Reload config; press `ctrl+o`; overlay appears
  5. Success: Single `ctrl+o` press opens overlay `[ref: PRD/Feature 3 AC]`; no orphaned chord bindings remain

- [ ] **T2.3 Phase 2 Validation** `[activity: validate]`

  Verify `which_key.py` exists and is valid Python. Reload config. Manually test all three actions from overlay: `w` (session picker), `l` (last session), `s` (save prompt). Verify tab colour changes on open and resets on close.

  Verify `kitten @ action goto_session` dispatches correctly — if `kitten @ action` does not accept `goto_session` as an argument, apply the deviation protocol: switch to `kitten @ goto-session` (hyphenated form) and update the `dispatch()` call accordingly.

---

### Phase 3: Integration & E2E Validation

Full end-to-end verification across all acceptance criteria.

- [ ] **T3.1 E2E: Session switch flow** `[activity: e2e-test]`

  Complete journey: press `ctrl+o` → overlay appears → press `w` → session picker opens → select session → tab bar updates with new session name.

  `[ref: PRD/Primary User Journey: Switching Sessions]`

- [ ] **T3.2 E2E: Save session flow** `[activity: e2e-test]`

  Complete journey: arrange panes → press `ctrl+o` → press `s` → type name → file created at `~/.config/kitty/sessions/<name>.kitty-session` → file loadable via `ctrl+o>w` picker.

  `[ref: PRD/Secondary User Journey: Saving the current session]`

- [ ] **T3.3 E2E: Edge cases** `[activity: e2e-test]`

  - Press `ctrl+o` → press Escape → overlay closes, no action, tab colour restored `[ref: PRD/Feature 3 AC]`
  - Press `ctrl+o` → press unrecognised key → same as Escape `[ref: PRD/Feature 3 AC]`
  - Press `ctrl+o` → press `s` → type empty name → overlay closes, no file created `[ref: SDD/Error Handling]`
  - Open kitty with no sessions loaded → tab titles show `N: title` (no prefix) `[ref: PRD/Feature 2 AC]`

- [ ] **T3.4 Specification Compliance** `[activity: business-acceptance]`

  | PRD Acceptance Criterion | Task | Verified |
  |--------------------------|------|---------|
  | Tab bar at top | T1.1 | ⬜ |
  | Named session shows prefix in tab titles | T1.2 | ⬜ |
  | No-session tabs show no prefix | T1.2 | ⬜ |
  | `ctrl+o` opens overlay with hint table | T2.1, T2.2 | ⬜ |
  | Valid key executes and closes | T2.1 | ⬜ |
  | Escape closes without action | T2.1 | ⬜ |
  | Tab colour changes on overlay open | T2.1 | ⬜ |
  | Tab colour resets on overlay close | T2.1 | ⬜ |
  | Save flow prompts for name only | T2.1 | ⬜ |
  | Empty name aborts save | T2.1 | ⬜ |

---

## Plan Verification

| Criterion | Status |
|-----------|--------|
| A developer can follow this plan without additional clarification | ✅ |
| Every task produces a verifiable deliverable | ✅ |
| All PRD acceptance criteria map to specific tasks | ✅ |
| All SDD components have implementation tasks | ✅ |
| Dependencies are explicit with no circular references | ✅ |
| Parallel opportunities are marked with `[parallel: true]` | ✅ (Phase 1 tasks can run in parallel) |
| Each task has specification references `[ref: ...]` | ✅ |
| Project commands in Context Priming are accurate | ✅ |
