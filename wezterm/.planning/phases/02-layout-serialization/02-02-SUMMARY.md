---
phase: 02-layout-serialization
plan: 02
subsystem: session-state
tags: [auto-save, throttle, update-status, call_after]
requirements:
  - REQ-09
dependency_graph:
  requires:
    - 02-01 (state module with save_current_workspace)
  provides:
    - Automatic workspace serialization on tab/pane activity
    - JSON session files in sessions/ directory
  affects:
    - Phase 5 (restoration reads these session files)
tech_stack:
  added:
    - wezterm.time.call_after for throttled saves
  patterns:
    - Throttle pattern (save_pending flag) instead of debounce for high-frequency events
    - pcall wrapping for error visibility in timer callbacks
    - tab:tab_id() comparison for active tab detection (MuxTab has no is_active())
key_files:
  created:
    - sessions/default.json (auto-generated workspace state)
  modified:
    - wezterm.lua (auto-save wiring in update-status handler)
    - lua/session/state.lua (is_active fix for MuxTab)
decisions:
  - "Throttle instead of debounce: update-status fires too frequently for debounce to ever trigger"
  - "Use tab:tab_id() == active_tab_id instead of tab:is_active() which doesn't exist on MuxTab"
  - "pcall wrapper in timer callback to surface errors via wezterm.log_error"
  - "Guard auto-save behind session_manager.enabled flag"
metrics:
  duration_seconds: 480
  completed_date: "2026-03-14"
---

# Phase 02 Plan 02: Auto-Save Wiring Summary

**Throttled auto-save via update-status event with MuxTab active-tab detection fix**

## Performance

- **Duration:** ~8 min (including debugging)
- **Tasks:** 2/2 complete
- **Files modified:** 2

## Accomplishments
- Auto-save triggers every 2 seconds during terminal activity
- JSON session files accurately reflect workspace state (tabs, panes, CWDs, processes)
- Human-verified: opening/closing tabs updates the session file
- All existing features confirmed working (theme toggle, smart-splits, daily notes, hints bar)

## Task Commits

1. **Task 1: Wire auto-save into update-status handler** - `0825f0c` (feat)
2. **Bug fix: MuxTab is_active + debounce-to-throttle** - `5ba60b2` (fix)
3. **Task 2: Human verification** - approved by user

## Files Created/Modified
- `wezterm.lua` - Added throttled auto-save in update-status handler
- `lua/session/state.lua` - Fixed tab:is_active() → tab:tab_id() comparison

## Decisions Made
1. **Throttle over debounce** — `update-status` fires on every cursor move/status change. Debounce (generation counter) never triggers because each event invalidates the previous timer. Throttle (save_pending flag) ensures saves happen every 2 seconds.
2. **tab:tab_id() comparison** — `MuxTab:is_active()` doesn't exist despite docs suggesting it does. Used `window:active_tab():tab_id()` comparison instead.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] MuxTab:is_active() does not exist**
- **Found during:** Human verification (Task 2)
- **Issue:** `capture_workspace()` crashed with `attempt to call a nil value (method 'is_active')`
- **Fix:** Used `window:active_tab()` + `tab:tab_id()` comparison for active tab detection
- **Files modified:** lua/session/state.lua
- **Verification:** Session file created successfully with correct active tab data
- **Committed in:** 5ba60b2

**2. [Rule 3 - Blocking] Debounce pattern incompatible with update-status frequency**
- **Found during:** Human verification (Task 2)
- **Issue:** Generation counter debounce never fires because update-status fires faster than 2-second window
- **Fix:** Switched to throttle pattern using `save_pending` boolean flag
- **Files modified:** wezterm.lua
- **Verification:** Session file updates within ~2 seconds of tab changes
- **Committed in:** 5ba60b2

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Both fixes essential for functionality. No scope creep.

## Issues Encountered
- WezTerm debug overlay (CTRL+SHIFT+L) not available — used diagnostic probe file (`debug-probe.txt`) written directly from update-status handler to isolate the is_active error

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Session serialization fully operational — JSON files auto-saved on activity
- Phase 5 (Layout Restoration) can read these files via `session.state.load_workspace()`
- No blockers

## Self-Check: PASSED

- ✅ All 6 Phase 2 tests pass
- ✅ Session file created with valid JSON structure
- ✅ Auto-save updates on tab/pane changes (human verified)
- ✅ All existing features work without regression (human verified)
