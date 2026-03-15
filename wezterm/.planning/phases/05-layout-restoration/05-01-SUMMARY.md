---
phase: 05-layout-restoration
plan: 01
subsystem: session-restoration
tags: [session-management, layout-restoration, workspace-management]
one_liner: "Session restoration API with smart attach routing and geometry-based pane reconstruction"
requirements_completed:
  - REQ-03
  - REQ-04
dependency_graph:
  requires:
    - 03-01-SUMMARY.md
  provides:
    - attach_session() - smart routing between switch and restore
    - restore_session() - full layout reconstruction from JSON
    - RESTORABLE_PROCESSES - allowlist for process restoration
  affects:
    - lua/session/manager.lua
tech_stack:
  added:
    - MuxPane:split() Lua API with CLI fallback for pane splitting
  patterns:
    - TDD Wave 0 (test infrastructure before implementation)
    - Geometry-based split direction inference
    - Nil-safe process handling
    - First pane reuse (no fragile exit patterns)
key_files:
  created:
    - bin/test-phase5.sh
    - sessions/test-restore.json
  modified:
    - lua/session/manager.lua
decisions:
  - title: "Use MuxPane:split() Lua method over CLI for synchronous splits"
    rationale: "Avoids async ordering issues (Pitfall #3 from research). Auto-detects with CLI fallback for compatibility."
    alternatives: "wezterm cli split-pane (async, harder to coordinate)"
  - title: "First pane reuse pattern"
    rationale: "spawn_window returns initial pane - configure it instead of closing. Avoids fragile exit/kill patterns."
    alternatives: "Close initial pane and recreate (brittle)"
  - title: "RESTORABLE_PROCESSES allowlist"
    rationale: "Only restore known-safe processes (nvim, claude, npm). Shells spawn by default, unknown processes logged and skipped."
    alternatives: "Restore all processes (risk of unwanted side effects)"
metrics:
  duration_seconds: 145
  completed_at: "2026-03-14T20:09:12Z"
  tasks: 2
  files_modified: 3
  commits: 2
---

# Phase 05 Plan 01: Session Restoration Core Summary

**One-liner:** Session restoration API with smart attach routing and geometry-based pane reconstruction

## What Was Built

Implemented complete session restoration logic in `lua/session/manager.lua`, providing:

1. **Public API:**
   - `attach_session(name)` - Smart routing: switch if workspace running, restore if saved-only
   - `restore_session(name)` - Full layout reconstruction from JSON

2. **Internal Implementation:**
   - `_restore_layout()` - Tab structure creation (reuse first tab, spawn additional)
   - `_restore_tab_panes()` - Pane splits with geometry-based direction inference
   - `_configure_pane()` - Process restoration via send_text commands
   - `RESTORABLE_PROCESSES` - Allowlist for safe process restoration (nvim, claude, npm, node)

3. **Test Infrastructure:**
   - `bin/test-phase5.sh` - 10 structural tests following Wave 0 TDD pattern
   - `sessions/test-restore.json` - Sample 2-tab, 4-pane test layout

## Task Breakdown

### Task 1: Test Infrastructure (Wave 0)
**Commit:** 58c72bc
**Files:** bin/test-phase5.sh, sessions/test-restore.json

Created test suite with 10 structural tests:
1. Config syntax validation
2. Restore functions existence checks
3. RESTORABLE_PROCESSES table verification
4. Split direction logic detection
5. First pane reuse confirmation (no fragile exit patterns)
6. Nil-safe process handling verification
7. Sample JSON validation
8. Smart attach behavior detection
9. Missing CWD fallback verification
10. Tab title restoration detection

Wave 0 results: 2 PASS (config/JSON), 8 SKIP (implementation not yet present)

Created sample JSON with 2 tabs:
- Tab 1 "editor": side-by-side panes (nvim + zsh)
- Tab 2 "servers": stacked panes (npm + zsh)

### Task 2: Restoration Implementation (Wave 1)
**Commit:** 8f6c501
**Files:** lua/session/manager.lua

Extended manager.lua with 252 new lines implementing:

**Smart Attach Logic:**
- Checks `wezterm.mux.all_windows()` for running workspace
- Routes to `switch_session()` if active
- Routes to `restore_session()` if saved-only
- Returns error if session not found

**Restoration Flow:**
1. Load JSON via `state.load_workspace()`
2. Auto-save current workspace
3. Spawn new workspace with first pane's CWD
4. Iterate tabs: reuse first tab, spawn additional
5. Set tab titles from JSON
6. For each tab: configure first pane, split remaining panes
7. Infer split direction from geometry (left position comparison)
8. Send process launch commands for known processes

**Key Implementation Details:**
- **First pane reuse:** spawn_window returns initial pane - configure it directly (no close/recreate)
- **Split method auto-detection:** Tries `MuxPane:split()` Lua API first, falls back to CLI if unavailable
- **Nil-safe process handling:** Checks `if not pane_data.process` before operations
- **Home directory fallback:** Uses `wezterm.home_dir` when CWD missing
- **Shell detection:** zsh/bash/fish/sh spawn by default, no action needed
- **Process allowlist:** Only nvim, claude, npm, node restored via send_text
- **Unknown process handling:** Logged and skipped (no crash)
- **Partial restoration:** pcall wraps splits - failures logged, remaining panes continue

**Post-implementation results:** All 10 tests PASS (0 failed, 0 skipped)

## Deviations from Plan

None - plan executed exactly as written.

The plan anticipated potential issues with MuxPane:split() availability and specified both Lua API and CLI fallback approaches. Implementation followed this guidance precisely with auto-detection on first use.

## Testing Results

### Automated Tests
```bash
bash bin/test-phase5.sh
```

**Results:**
- PASSED: 10
- FAILED: 0
- SKIPPED: 0

All structural tests pass:
- ✓ Config syntax valid
- ✓ Restore functions exist
- ✓ RESTORABLE_PROCESSES defined
- ✓ Split direction logic present
- ✓ First pane reuse (no fragile exit)
- ✓ Nil-safe process handling
- ✓ Sample JSON valid (2 tabs, 4 panes)
- ✓ Smart attach behavior
- ✓ Missing CWD fallback
- ✓ Tab title restoration

### Structural Verification
```bash
# Function count (4 existing + 5 new = 9 total)
grep -c "function M\." lua/session/manager.lua
# Output: 9

# Test JSON structure
python3 -c "import json; d=json.load(open('sessions/test-restore.json')); print(f'{len(d[\"tabs\"])} tabs, {sum(len(t[\"panes\"]) for t in d[\"tabs\"])} panes')"
# Output: 2 tabs, 4 panes
```

## Technical Decisions

### 1. MuxPane:split() Lua API vs CLI
**Chosen:** Auto-detect Lua method with CLI fallback

**Rationale:**
- Research identified async ordering as Pitfall #3 with CLI approach
- MuxPane:split() is synchronous, returns MuxPane directly
- Auto-detection provides compatibility if API unavailable
- Logs which method used on first call for transparency

**Trade-offs:**
- Lua API: Synchronous, clean references, but may not exist in all WezTerm versions
- CLI fallback: Universal compatibility, but async and harder to coordinate

### 2. First Pane Reuse Pattern
**Chosen:** Configure spawn_window's initial pane directly

**Rationale:**
- spawn_window returns (tab, pane, window) - the pane already exists
- Closing and recreating is fragile (timing issues, empty workspace flicker)
- Configuring in-place is atomic and safe

**Trade-offs:**
- Reuse: Simple, atomic, matches spawn_window contract
- Recreate: Would require send_text("exit\n") or kill-pane (brittle)

### 3. RESTORABLE_PROCESSES Allowlist
**Chosen:** Explicit allowlist of known-safe processes

**Rationale:**
- Some processes have side effects (email clients, database tools)
- Shells spawn by default when no process specified
- Better to skip unknown than risk unwanted launches

**Trade-offs:**
- Allowlist: Safe, explicit, requires maintenance
- Restore all: Automatic, but risk of side effects

### 4. Geometry-Based Split Direction
**Chosen:** Compare `left` positions to infer side-by-side vs stacked

**Rationale:**
- JSON doesn't store explicit split direction
- Geometry is the only signal available
- Algorithm: if `pane.left > prev.left + prev.width/2`, split right; else bottom

**Trade-offs:**
- Geometry inference: Works for typical 2-4 pane layouts, may degrade for complex grids
- Explicit direction: Would require schema change and reserialization

## Artifacts

### Public API (lua/session/manager.lua)

```lua
-- Smart attach: switch to running workspace or restore from JSON
-- @param name: session name
-- @return: true on success, nil + error message on failure
function M.attach_session(name)

-- Restore session from JSON (full layout reconstruction)
-- @param name: session name
-- @return: true on success, nil + error message on failure
function M.restore_session(name)
```

### Process Allowlist

```lua
local RESTORABLE_PROCESSES = {
  nvim = "nvim",
  claude = "claude",
  npm = "npm run dev",
  node = "node",
}
```

### Test Infrastructure

**bin/test-phase5.sh:**
- 10 structural tests covering all success criteria
- Wave 0 TDD pattern (tests created before implementation)
- Color output, verbose mode, test filtering
- Exit codes: 0 (all pass), 1 (failures), 2 (skips)

**sessions/test-restore.json:**
- 2 tabs: "editor" (side-by-side), "servers" (stacked)
- 4 panes total demonstrating both split directions
- Mix of nvim, npm, and zsh processes
- Valid JSON schema matching Phase 2 serialization format

## Integration Points

### Dependencies
- `lua/session/state.lua` - load_workspace(), save_current_workspace()
- `wezterm.mux` - spawn_window(), all_windows(), MuxPane API
- Phase 03-01 - Existing CRUD operations (create, list, switch, delete)

### Provides
- `attach_session()` - Used by CLI (Phase 04) and keybindings (Phase 06)
- `restore_session()` - Used by attach_session and direct restoration
- `RESTORABLE_PROCESSES` - Extensible allowlist for future processes

### Affects
- manager.lua extended from 217 to 469 lines
- No breaking changes to existing functions
- All Phase 03 functionality preserved

## Known Limitations

1. **Complex Layout Accuracy:**
   - Geometry inference works well for 2-4 pane layouts
   - May degrade for 5+ panes or complex grids
   - Plan logs warning for pane index > 4

2. **Process Restoration Scope:**
   - Only nvim, claude, npm, node in allowlist
   - Users running other editors/tools will see skipped process logs
   - Extensible via RESTORABLE_PROCESSES table

3. **CLI Split Fallback:**
   - If Lua API unavailable, CLI fallback loses pane references
   - Can't call _configure_pane on CLI-created panes
   - Logged but continues with remaining panes

4. **Active Tab Tracking:**
   - Restores tab titles and structure
   - Does NOT restore which tab was active (Phase 2 captures it, Phase 5 ignores it)
   - Future enhancement if user feedback indicates need

## Next Steps

Phase 05 has 1 additional plan:
- **05-02-PLAN.md:** CLI integration and keybindings for restoration

This plan provides the core API. Next plan will wire it to user-facing commands.

## Self-Check

### File Existence Verification

```bash
# Check created files exist
[ -f "bin/test-phase5.sh" ] && echo "FOUND: bin/test-phase5.sh" || echo "MISSING: bin/test-phase5.sh"
[ -f "sessions/test-restore.json" ] && echo "FOUND: sessions/test-restore.json" || echo "MISSING: sessions/test-restore.json"

# Check modified file exists
[ -f "lua/session/manager.lua" ] && echo "FOUND: lua/session/manager.lua" || echo "MISSING: lua/session/manager.lua"
```

### Commit Verification

```bash
# Check Task 1 commit exists
git log --oneline --all | grep -q "58c72bc" && echo "FOUND: 58c72bc" || echo "MISSING: 58c72bc"

# Check Task 2 commit exists
git log --oneline --all | grep -q "8f6c501" && echo "FOUND: 8f6c501" || echo "MISSING: 8f6c501"
```

### Execution Verification

```bash
# Run test suite
bash bin/test-phase5.sh
# Expected: PASSED: 10, FAILED: 0, SKIPPED: 0

# Verify function count
grep -c "function M\." lua/session/manager.lua
# Expected: 9

# Verify test JSON structure
python3 -c "import json; d=json.load(open('sessions/test-restore.json')); print(f'{len(d[\"tabs\"])} tabs, {sum(len(t[\"panes\"]) for t in d[\"tabs\"])} panes')"
# Expected: 2 tabs, 4 panes
```

Running self-check...

**Results:**

```
FOUND: bin/test-phase5.sh
FOUND: sessions/test-restore.json
FOUND: lua/session/manager.lua
FOUND: 58c72bc (Task 1 commit)
FOUND: 8f6c501 (Task 2 commit)

Test suite: PASSED: 10, FAILED: 0, SKIPPED: 0
Function count: 9
Test JSON: 2 tabs, 4 panes
```

## Self-Check: PASSED

All files created, all commits present, all tests passing.
