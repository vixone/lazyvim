---
phase: 04-shell-cli
plan: 01
subsystem: cli
tags: [bash, wezterm-cli, session-management, json]

# Dependency graph
requires:
  - phase: 03-session-manager-core
    provides: Session manager Lua API and persistence layer
provides:
  - Shell-facing CLI for session CRUD operations
  - Bash-side JSON serialization compatible with state.lua
  - Human-friendly session list with status and timestamps
  - Safe delete with confirmation and default protection
affects: [05-layout-restore, 06-keyboard-bindings]

# Tech tracking
tech-stack:
  added: [python3 for JSON parsing in bash]
  patterns:
    - "Bash CLI routing pattern with unified help"
    - "wezterm cli list --format json for mux state queries"
    - "Bash-side JSON generation matching Lua schema"

key-files:
  created: [bin/test-phase4.sh]
  modified: [bin/wez-session]

key-decisions:
  - "Unified help text with Session/Daemon command groups instead of separate wez-session-* binaries"
  - "python3 for JSON parsing in bash (always available on macOS, cleaner than jq/sed/awk)"
  - "Bash-side save implementation for CLI self-containment"
  - "kill-pane command for workspace cleanup instead of send-text exit"

patterns-established:
  - "Session CLI pattern: create/list/save/delete subcommands"
  - "wezterm cli spawn --new-window --workspace for session creation"
  - "wezterm cli kill-pane --pane-id for clean pane termination"
  - "Relative time formatting for human-friendly timestamps"

requirements-completed: [REQ-07]

# Metrics
duration: 4min
completed: 2026-03-14
---

# Phase 4 Plan 1: Shell CLI Implementation Summary

**Bash CLI wrapper with session CRUD commands (create, list, save, delete) bridging shell-side operations to WezTerm mux server**

## Performance

- **Duration:** 4 minutes
- **Started:** 2026-03-14T19:26:00Z
- **Completed:** 2026-03-14T19:26:04Z
- **Tasks:** 3 (2 auto + 1 checkpoint)
- **Files modified:** 2

## Accomplishments
- Unified CLI with session and daemon command groups in single binary
- Complete session lifecycle: create → list → save → delete
- Human-friendly list output with active markers, status, and relative timestamps
- Safe delete with confirmation prompt and default workspace protection
- Bash-side JSON serialization compatible with state.lua format
- 12-test automated test suite covering structure and validation

## Task Commits

Each task was committed atomically:

1. **Task 1: Add session subcommands to wez-session CLI** - `4977f9f` (feat)
2. **Task 2: Create phase 4 test script** - `78e24dd` (test)
3. **Task 3: Verify CLI end-to-end** - User approved after checkpoint

**Bug fixes (post-checkpoint):** `b2ab491` (fix)

## Files Created/Modified
- `bin/wez-session` - Added session_create, session_list, session_save, session_delete functions with unified help
- `bin/test-phase4.sh` - Automated test suite with 12 structural and validation tests
- `sessions/*.json` - Session state files created by save command

## Decisions Made

1. **Unified help text instead of separate binaries** - Single `wez-session` command with Session/Daemon sections is simpler than `wez-session-*` family. Reduces PATH clutter, clearer UX.

2. **python3 for JSON parsing in bash** - Always available on macOS, cleaner than jq (not pre-installed) or sed/awk regex parsing. Single-line invocations keep scripts readable.

3. **Bash-side save implementation** - CLI captures `wezterm cli list --format json` and generates JSON directly in bash instead of calling Lua. Keeps CLI self-contained and avoids complex IPC.

4. **kill-pane for workspace cleanup** - Replaced `send-text "exit\n"` with `wezterm cli kill-pane --pane-id` for reliable pane termination during delete operations.

## Deviations from Plan

### Auto-fixed Issues (post-checkpoint)

**1. [Rule 1 - Bug] Fixed missing --new-window flag for wezterm cli spawn**
- **Found during:** Task 3 checkpoint verification (user testing)
- **Issue:** `wezterm cli spawn --workspace` alone didn't create visible workspace - command completed but no window appeared
- **Fix:** Added `--new-window` flag: `wezterm cli spawn --new-window --workspace "$name"`
- **Files modified:** bin/wez-session (session_create function)
- **Verification:** `wez-session create test` now opens visible WezTerm window
- **Committed in:** b2ab491

**2. [Rule 1 - Bug] Fixed help text exit code**
- **Found during:** Task 3 checkpoint verification (test suite)
- **Issue:** `wez-session --help` exited with code 1 (error) instead of 0 (success)
- **Fix:** Changed help case to explicitly `exit 0` after printing help text
- **Files modified:** bin/wez-session (main routing)
- **Verification:** `wez-session --help; echo $?` returns 0
- **Committed in:** b2ab491

**3. [Rule 1 - Bug] Fixed pane cleanup in session_delete**
- **Found during:** Task 3 checkpoint verification (delete testing)
- **Issue:** `send-text "exit"` sent literal text without newline - panes showed "exit" prompt but didn't terminate
- **Fix:** Replaced with `wezterm cli kill-pane --pane-id "$pane_id"` for immediate termination
- **Files modified:** bin/wez-session (session_delete function)
- **Verification:** `wez-session delete -f test-session` cleanly removes all panes
- **Committed in:** b2ab491

---

**Total deviations:** 3 auto-fixed bugs (all Rule 1)
**Impact on plan:** All fixes discovered during checkpoint verification. Core implementation correct, but CLI invocation details needed runtime testing. No scope creep.

## Issues Encountered

None during planned implementation - bugs found during checkpoint verification were fixed immediately per deviation rules.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 5 (Layout Restore) can proceed:
- Session save generates JSON with tab/pane structure
- Session list shows what's available to restore
- JSON format matches state.lua schema for bidirectional compatibility
- CLI provides shell-side operations for automation/scripting

**Note for Phase 5:** Layout restoration will need to handle:
- Tab recreation with correct titles
- Pane splits with geometry (left/top/width/height from JSON)
- Process restoration (if possible - `get_foreground_process_name()` returns nil for mux panes)
- CWD restoration for each pane

## Self-Check: PASSED

All claimed files and commits verified:
- ✓ bin/wez-session exists
- ✓ bin/test-phase4.sh exists
- ✓ Commit 4977f9f exists (Task 1)
- ✓ Commit 78e24dd exists (Task 2)
- ✓ Commit b2ab491 exists (Bug fixes)

---
*Phase: 04-shell-cli*
*Completed: 2026-03-14*
