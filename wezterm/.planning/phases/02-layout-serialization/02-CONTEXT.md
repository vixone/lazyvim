# Phase 2: Layout Serialization - Context

**Gathered:** 2026-03-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Capture current workspace state (tabs, pane splits, working directories, running processes) to a human-readable, git-versionable JSON file in `sessions/`. This is the persistence layer — the mux daemon keeps panes alive in memory, but serialization ensures state survives mux restarts, machine reboots, and enables portability. Layout restoration from JSON is Phase 5.

</domain>

<decisions>
## Implementation Decisions

### Save trigger
- Auto-save on workspace changes (tab open/close, pane split/close) — zero user effort
- No manual save keybinding — auto-save is sufficient for now (can add CMD+SHIFT+S later if needed)
- Save captures the active workspace only, not all workspaces at once — each workspace saves independently when the user interacts with it

### File strategy
- One JSON file per workspace — e.g., `sessions/default.json`, `sessions/project-x.json`
- Clean git diffs: saving one workspace doesn't touch other session files
- Aligns with Phase 3 session naming (one session = one workspace = one file)

### Claude's Discretion
- JSON schema structure and field naming (must be human-readable and produce clean diffs)
- Layout complexity scope — roadmap flags complex nested splits as risky (Pitfall #2), Claude decides MVP scope
- Process capture depth — foreground process name vs full command with args
- Nil-safe patterns for `get_foreground_process_name()` and `get_current_working_dir()` (both can return nil for mux panes)
- Platform-aware `file:///` URI parsing via `wezterm.target_triple`
- Auto-save debouncing/throttling strategy to avoid excessive writes
- What WezTerm events to hook into for detecting workspace changes

</decisions>

<specifics>
## Specific Ideas

- User is happy with current mux daemon persistence behavior (Phase 1) — serialization is the "insurance policy" for when mux state is lost
- User wants persistence to be automatic and invisible — "it just works" without remembering to save
- One file per workspace keeps git history clean and matches the mental model of "one session = one file"

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lua/session/init.lua` — entry point, `apply_to_config()` pattern for wiring into config
- `lua/session/daemon.lua` — `DOMAIN_NAME`, `is_connected(pane)`, `get_status(pane)` for mux awareness
- `wezterm.GLOBAL` — already used for tab lock state, can hold serialization state/timers
- `update-status` event handler — already runs on pane activity, potential hook point for auto-save
- `sessions/` directory already exists from Phase 1 scaffolding

### Established Patterns
- Lua module pattern: `local M = {}` with functions, `return M`
- `pcall(require, ...)` for graceful module loading (used for session module in wezterm.lua)
- `wezterm.config_dir` for file paths
- `wezterm.run_child_process` for shell commands
- `io.open` for file I/O (used in theme-mode read/write)

### Integration Points
- New module: `lua/session/state.lua` (referenced in Phase 1 STATE.md as planned)
- WezTerm events for auto-save: `window-config-reloaded`, `update-status`, or custom event triggers
- `window:mux_window()` → `mux_window:tabs()` → `tab:panes_with_info()` for introspecting layout
- `pane:get_current_working_dir()` for CWDs (returns URI object or nil)
- `pane:get_foreground_process_name()` for running process detection (returns string or nil)
- `wezterm.mux.get_active_workspace()` for workspace name (becomes the filename)

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-layout-serialization*
*Context gathered: 2026-03-14*
