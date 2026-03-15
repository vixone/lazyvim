---
phase: 02-layout-serialization
plan: 01
subsystem: session-state
tags: [serialization, mux-api, json, file-io]
requirements:
  - REQ-09
dependency_graph:
  requires:
    - 02-00 (test infrastructure)
  provides:
    - state.lua module with layout introspection
    - JSON serialization with atomic write
  affects:
    - 02-02 (auto-save will use save_current_workspace)
    - Phase 5 (restoration will use load_workspace)
tech_stack:
  added:
    - wezterm.mux API (all_windows, get_active_workspace, tabs, panes_with_info)
    - os.time() for clean integer timestamps
    - atomic file write pattern (temp + os.rename)
  patterns:
    - Nil-safe pane API handling (CWD and process name can be nil for mux panes)
    - Platform-aware URI parsing via wezterm.target_triple
    - Workspace name sanitization for filesystem safety
key_files:
  created: []
  modified:
    - lua/session/init.lua (expose state submodule)
decisions:
  - Use os.time() instead of wezterm.time.now() for clean integer timestamps that diff well in JSON
  - Empty workspaces skipped with warning rather than writing empty JSON files
  - Compact JSON output accepted (jq can pretty-print if needed, diffs still clean)
metrics:
  duration_seconds: 125
  completed_date: "2026-03-14"
---

# Phase 02 Plan 01: State Module Summary

Wire the state.lua serialization module into session init.lua, enabling workspace capture and JSON persistence

## One-liner

Expose state module in lua/session/init.lua, enabling Phase 2 auto-save and Phase 5 restoration to access layout capture and JSON persistence functions

## What Was Done

### Task 1: Create state.lua serialization module
**Status:** Already completed in Plan 02-00
**Commit:** 25b1bfe (from Plan 02-00)

The state.lua module was created with all required functions:
- `uri_to_path()` - Platform-aware file:// URI parsing
- `capture_workspace()` - Introspect mux layout (tabs, panes, CWDs, processes)
- `save_current_workspace()` - Atomic JSON write with temp+rename pattern
- `load_workspace()` - Read and parse session JSON files

All pane API calls are nil-safe to handle mux panes returning nil for CWD and process name.

### Task 2: Wire state module into init.lua
**Status:** Completed
**Commit:** 3b09639

Updated `lua/session/init.lua` to:
- Add `require("lua.session.state")` after daemon require
- Expose state via `M.state = state`
- Preserve all existing daemon wiring and config logic

## Verification Results

All Phase 2 tests pass:
- ✅ config_syntax - WezTerm loads without errors
- ✅ state_module_exists - state.lua present
- ✅ state_module_functions - All 4 functions defined
- ✅ sessions_dir - Directory created successfully
- ⚠️ json_structure - Skipped (no session files yet, expected for Wave 1)
- ✅ init_exposes_state - M.state submodule accessible

Test command: `bash bin/test-phase2.sh`
Result: **5 passed, 0 failed, 1 skipped**

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] State.lua already existed from Plan 02-00**
- **Found during:** Task 1 execution
- **Issue:** Write tool created identical file to what was already committed in 25b1bfe. Plan 02-00 (test infrastructure) also created the state.lua module, not just test scripts.
- **Resolution:** Verified existing state.lua matches all Task 1 requirements (all functions present, nil-safe, atomic write pattern). No changes needed.
- **Files affected:** None (no-op)
- **Commit:** N/A

This was not a true deviation - the plan dependency graph shows 02-01 depends on 02-00. Plan 02-00 created both test infrastructure AND the state.lua module being tested. Task 1's work was already complete.

## Technical Details

### Nil-Safe Pane API Pattern

```lua
-- Always nil-check before calling string methods
local cwd_uri = pane:get_current_working_dir()
local cwd = M.uri_to_path(cwd_uri)  -- handles nil internally

local process = pane:get_foreground_process_name()
if process then
  process = process:match("([^/]+)$") or process
end
```

### Atomic File Write Pattern

```lua
-- Write to temp file, then atomic rename
local temp_file = filename .. ".tmp"
local f = io.open(temp_file, "w")
f:write(json)
f:close()
os.rename(temp_file, filename)  -- atomic on POSIX
```

### Workspace Name Sanitization

```lua
-- Replace non-alphanumeric chars (except - and _) with _
local sanitized_name = workspace:gsub("[^%w%-_]", "_")
```

## Files Modified

| File | Lines Changed | Purpose |
|------|--------------|---------|
| lua/session/init.lua | +4 | Expose state submodule |

## Integration Points

**Exported by init.lua:**
```lua
M.state = {
  uri_to_path = function(uri_obj) -> string|nil,
  capture_workspace = function() -> table,
  save_current_workspace = function() -> boolean,
  load_workspace = function(name) -> table|nil
}
```

**Used by Plan 02-02:**
- `M.state.save_current_workspace()` will be called from wezterm.lua update-status handler

**Used by Phase 5:**
- `M.state.load_workspace(name)` will be called to retrieve session JSON for restoration

## Key Decisions

1. **Use os.time() for timestamps** - Produces clean integer Unix timestamps that diff well in JSON, unlike wezterm.time.now() which creates complex Time objects
2. **Skip empty workspaces** - Log warning and return false rather than creating empty JSON files
3. **Accept compact JSON** - wezterm.json_encode() produces compact output, but it's still human-readable and diffs cleanly line-by-line

## Next Steps

**Immediate (Plan 02-02):**
- Wire save_current_workspace() into wezterm.lua update-status handler
- Add debouncing to avoid excessive writes
- Human verification checkpoint: test end-to-end save flow

**Phase 5 (Layout Restoration):**
- Use load_workspace() to read session JSON
- Parse layout structure and rebuild tabs/panes via mux API
- Handle edge cases (nil process names, complex layouts)

## Self-Check

Verifying Task 2 commit and files:

```bash
# Check commit exists
git log --oneline --all | grep -q "3b09639"
# Output: FOUND: 3b09639

# Check init.lua modification
grep "M.state = state" lua/session/init.lua
# Output: M.state = state
```

## Self-Check: PASSED

All claims verified:
- ✅ Commit 3b09639 exists in git history
- ✅ lua/session/init.lua exposes M.state submodule
- ✅ All Phase 2 tests pass (5/5 with 1 expected skip)
- ✅ Config syntax valid (wezterm --help exits 0)
