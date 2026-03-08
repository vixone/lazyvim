---
title: "Claude Screenshot Paste in Kitty Terminal"
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
- [x] Activity hints provided for specialist selection
- [x] Every phase references relevant SDD sections
- [x] Every test references PRD acceptance criteria
- [x] Integration & E2E test defined in final phase
- [x] Project commands match actual project setup

---

## Specification Compliance Guidelines

### Deviation Protocol

When implementation requires changes from the specification:
1. Document the deviation with clear rationale
2. Obtain approval before proceeding
3. Update SDD when the deviation improves the design

---

## Metadata Reference

- `[ref: document/section]` — Links to specification sections
- `[activity: type]` — Activity hint for specialist agent selection

---

## Context Priming

*GATE: Read all files in this section before starting any implementation.*

**Specification**:
- `docs/specs/004-claude-screenshot-paste/product-requirements.md` — Product Requirements (PRD)
- `docs/specs/004-claude-screenshot-paste/solution-design.md` — Solution Design (SDD)

**Existing codebase** (read before modifying):
- `~/.config/kitty/keybindings.conf` — Existing keybindings; new line goes under `# ─── CLIPBOARD ─────` section
- `~/.config/kitty/save_session.sh` — Reference pattern for zsh helper scripts
- `~/.config/kitty/kitty.conf` — Verify `allow_remote_control yes` and `listen_on unix:/tmp/kitty` are present (no change needed)

**Key Design Decisions**:
- **ADR-1**: Clipboard extraction → `kitten clipboard -g /tmp/screenshot_$(date +%s).png` (bundled, no install)
- **ADR-2**: Script location → `~/.config/kitty/paste_screenshot.sh` (follows `save_session.sh` pattern)
- **ADR-3**: Keybinding → `cmd+shift+v` (natural "special paste", no conflicts)

**Implementation Context**:
```bash
# Reload kitty config after changes (no restart needed)
Reload:  Ctrl+Shift+F5

# Manual smoke tests (run before E2E)
Test-1:  kitten clipboard -g /tmp/test_ss.png && echo "OK: $(ls -lh /tmp/test_ss.png)"
Test-2:  kitten @ --to unix:/tmp/kitty send-text --match window:focused "/tmp/test_ss.png"
```

---

## Implementation Phases

Each task follows: **Prime** (understand context) → **Test** (verify what should happen) → **Implement** (build it) → **Validate** (confirm it works)

---

### Phase 1: Script + Keybinding

Delivers the two files that constitute the complete feature. T1.2 depends on T1.1 (script must exist before binding points to it).

---

- [ ] **T1.1 Create `paste_screenshot.sh`** `[activity: shell-scripting]`

  1. **Prime**: Read `[ref: SDD/Implementation Examples]` for the exact script logic and gotchas. Read `save_session.sh` for script conventions (zsh shebang, minimal logic).
  2. **Test**:
     - Take a screenshot with `Ctrl+Cmd+Shift+4` so clipboard has an image
     - Manually run `kitten clipboard -g /tmp/test_ss.png` → expect exit 0 and PNG file created
     - Manually run without an image in clipboard → expect exit non-zero (no file created)
     - Manually run `kitten @ --to unix:/tmp/kitty send-text --match window:focused "/tmp/test_ss.png"` → expect path appears in active window
  3. **Implement**: Create `~/.config/kitty/paste_screenshot.sh`:
     ```
     #!/bin/zsh
     TMPFILE="/tmp/screenshot_$(date +%s).png"
     if kitten clipboard -g "$TMPFILE" 2>/dev/null; then
         kitten @ --to unix:/tmp/kitty send-text --match window:focused "$TMPFILE"
     fi
     ```
     Make executable: `chmod +x ~/.config/kitty/paste_screenshot.sh`
  4. **Validate**: Run `bash -n ~/.config/kitty/paste_screenshot.sh` (syntax check). Run manual tests from step 2.
  5. **Success**:
     - [ ] Script exits cleanly when clipboard has image; PNG file exists at `/tmp/screenshot_TIMESTAMP.png` `[ref: PRD/AC Feature 1, criterion 1]`
     - [ ] Script exits cleanly when clipboard has no image; no file created, no path injected `[ref: PRD/AC Feature 1, criterion 4]`
     - [ ] `kitten @ send-text` injects path at cursor in active window `[ref: SDD/Runtime View, Primary Flow step 8]`

---

- [ ] **T1.2 Add `cmd+shift+v` keybinding** `[activity: kitty-config]`

  1. **Prime**: Read `[ref: keybindings.conf, lines 58-62]` — the existing `# ─── CLIPBOARD` section. The new binding must go directly under `cmd+c` following the exact comment and format conventions. Read `[ref: SDD/Implementation Examples, keybindings.conf addition]` for the exact two lines to add.
  2. **Test**: Confirm `cmd+shift+v` is not already bound: `grep -n "cmd+shift+v" ~/.config/kitty/keybindings.conf` → expect no output.
  3. **Implement**: Add to `keybindings.conf` under the CLIPBOARD section:
     ```
     # Extracts clipboard screenshot (Ctrl+Cmd+Shift+4) to /tmp/screenshot_TIMESTAMP.png
     # and inserts the file path at the Claude Code CLI prompt. No newline appended.
     map cmd+shift+v launch --type=background zsh ~/.config/kitty/paste_screenshot.sh
     ```
  4. **Validate**: Reload Kitty config with `Ctrl+Shift+F5`. No errors shown. Confirm binding registered: `kitten @ --to unix:/tmp/kitty get-text` (or visually confirm in Kitty).
  5. **Success**:
     - [ ] `grep "cmd+shift+v" ~/.config/kitty/keybindings.conf` returns the new binding line `[ref: ADR-3]`
     - [ ] Kitty reloads config without errors `[ref: SDD/Deployment View]`
     - [ ] Binding appears in correct CLIPBOARD section with matching comment style `[ref: SDD/Directory Map]`

---

- [ ] **T1.3 Phase 1 Validation** `[activity: validate]`

  - Confirm `~/.config/kitty/paste_screenshot.sh` exists and is executable (`ls -la ~/.config/kitty/paste_screenshot.sh`)
  - Confirm keybinding is present in correct section (`grep -A2 "CLIPBOARD" ~/.config/kitty/keybindings.conf`)
  - Confirm no existing bindings were disturbed (`grep -c "map " ~/.config/kitty/keybindings.conf` — count should be exactly 1 higher than before)

---

### Phase 2: End-to-End Verification

Full user journey validation. All PRD acceptance criteria exercised manually.

---

- [ ] **T2.1 Happy path E2E test** `[activity: e2e-test]`

  1. **Prime**: Read `[ref: PRD/User Journey Maps, Primary User Journey]` — the full 5-step flow.
  2. **Test scenario — region screenshot**:
     1. Press `Ctrl+Cmd+Shift+4`, draw a region → screenshot in clipboard
     2. Switch to Kitty window with Claude Code CLI (at input prompt)
     3. Press `Cmd+Shift+V`
     4. Observe: `/tmp/screenshot_<timestamp>.png` appears at cursor
     5. Verify file exists: `ls -la /tmp/screenshot_<timestamp>.png`
     6. Type a question after the path and press Enter
     7. Observe: Claude Code receives and processes the image
  3. **Test scenario — full screen screenshot**:
     - Repeat with `Ctrl+Cmd+Shift+3` (full screen to clipboard) → same outcome expected
  4. **Success**:
     - [ ] Path appears at cursor within ~500ms `[ref: SDD/Quality Requirements]`
     - [ ] No newline is appended — user must press Enter manually `[ref: PRD/Feature Requirements, Won't Have]`
     - [ ] PNG file is valid and accepted by Claude Code `[ref: PRD/AC Feature 2, criterion 3]`
     - [ ] Claude Code successfully reads the image and responds `[ref: PRD/User Journey Maps, step 4]`

---

- [ ] **T2.2 Error path E2E test** `[activity: e2e-test]`

  1. **Prime**: Read `[ref: SDD/Runtime View, Error Handling table]`
  2. **Test scenario — no image in clipboard**:
     1. Copy some text (ensure clipboard has text, not image)
     2. Press `Cmd+Shift+V` in Kitty
     3. Observe: nothing happens — no path inserted, no error shown
  3. **Test scenario — rapid successive presses**:
     1. Take a screenshot → press `Cmd+Shift+V` twice quickly (within 1 second)
     2. Observe: if two files created, they should have different names (or same name if within same second — check both are safe)
  4. **Success**:
     - [ ] No phantom path inserted when clipboard has no image `[ref: PRD/AC Feature 1, criterion 4]`
     - [ ] No crash or visible error in terminal `[ref: SDD/Error Handling, row 1]`
     - [ ] Rapid presses do not corrupt the terminal prompt `[ref: SDD/Implementation Gotchas, timestamp collision]`

---

- [ ] **T2.3 Specification Compliance** `[activity: business-acceptance]`

  Final check that all PRD acceptance criteria are satisfied:

  | PRD Criterion | Verified By | Status |
  |---|---|---|
  | PNG file saved to `/tmp/screenshot_TIMESTAMP.png` | T2.1 happy path | ⬜ |
  | File path typed at cursor (no newline) | T2.1 step 4 | ⬜ |
  | Silent no-op when no image in clipboard | T2.2 error path | ⬜ |
  | No broken path injected on failure | T2.2 error path | ⬜ |
  | Path appears within ~500ms | T2.1 timing observation | ⬜ |
  | Claude Code accepts the image | T2.1 step 6-7 | ⬜ |

---

## Plan Verification

| Criterion | Status |
|-----------|--------|
| A developer can follow this plan without additional clarification | ✅ |
| Every task produces a verifiable deliverable | ✅ |
| All PRD acceptance criteria map to specific tasks | ✅ |
| All SDD components have implementation tasks | ✅ |
| Dependencies are explicit with no circular references | ✅ (T1.2 depends on T1.1; T2.x depends on Phase 1) |
| Each task has specification references `[ref: ...]` | ✅ |
| Project commands in Context Priming are accurate | ✅ |
