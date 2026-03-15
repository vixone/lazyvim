# Phase 3: Session Manager Core - Context

**Gathered:** 2026-03-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Lua API module (`lua/session/manager.lua`) for session lifecycle operations: create, list, switch, and delete named sessions (workspaces). This is the CRUD layer that Phase 4 (CLI) and Phase 6 (picker) will consume. Layout restoration from JSON is Phase 5 — this phase only handles workspace creation/switching/deletion and JSON file management.

</domain>

<decisions>
## Implementation Decisions

### Session creation flow
- Auto-save current workspace state before switching to the new session
- Create a new workspace and switch to it immediately
- Idempotent: if a session with that name already exists (running workspace or JSON file), switch to it instead of erroring
- New sessions start with a single empty shell pane at `~/` (home directory)
- No optional CWD argument — always starts at home

### Session naming rules
- Strict: alphanumeric characters, dashes, and underscores only
- Reject invalid names with a clear error message
- Matches the filename sanitization pattern already in `state.lua`

### Session listing
- Return per session: name, last_saved timestamp, active/saved status
- Sort by most recently saved first (natural for session switching)
- Include the 'default' workspace in the list — it's a real session
- Distinguish 'active' (workspace currently running in mux) vs 'saved' (JSON file exists but no running workspace)

### Session deletion
- Full cleanup: remove JSON file AND kill the workspace (close all tabs/panes)
- Active session deletion allowed — auto-switch to another session first (most recent, or 'default')
- Default workspace ('default') is protected — cannot be deleted
- No confirmation in the API — callers (CLI, picker) are responsible for confirmation prompts

### Session switching behavior
- Carried from Phase 2: auto-save triggers on workspace changes, so current session state is captured automatically
- Switching activates the target workspace (WezTerm workspace API)

### Claude's Discretion
- Internal API signatures and return types (tables, error codes, etc.)
- How to enumerate active workspaces vs JSON-only sessions for the list
- How to kill workspace panes on delete (iterate and close, or use WezTerm workspace API if available)
- Error handling patterns (return nil+error string, or boolean+message)
- Whether to add a `rename` operation (not in success criteria but may be natural)

</decisions>

<specifics>
## Specific Ideas

- "I want it to feel like tmux's always-on behavior" (from Phase 1) — session create should be as seamless as tmux new-session
- Idempotent create matches tmux behavior: `tmux new-session -s name` attaches if already exists
- The manager module should be the single entry point for all session operations — CLI and picker both call the same API

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lua/session/state.lua`: `save_current_workspace()`, `load_workspace(name)`, `capture_workspace()` — already handles JSON serialization and file I/O
- `lua/session/daemon.lua`: `DOMAIN_NAME` constant, `is_connected(pane)` for mux awareness
- `lua/session/init.lua`: `apply_to_config()` pattern for wiring modules into config
- `wezterm.GLOBAL` — used for tab lock state, can hold session manager state

### Established Patterns
- Lua module pattern: `local M = {}` with functions, `return M`
- Nil-safe patterns from state.lua (check before calling string methods)
- Atomic file write via temp file + rename (state.lua line 128-147)
- `pcall(require, ...)` for graceful module loading
- Sanitized filenames via `:gsub("[^%w%-_]", "_")` already in state.lua

### Integration Points
- New module: `lua/session/manager.lua` — requires state.lua and daemon.lua
- `wezterm.mux.get_active_workspace()` — for current session detection
- `wezterm.mux.all_windows()` — for iterating workspaces and their windows
- `wezterm.mux.spawn_window({workspace = name})` — for creating new workspaces (CAUTION: Pitfall #4 — avoid domain parameter)
- `sessions/` directory — JSON files already stored here by state.lua

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-session-manager-core*
*Context gathered: 2026-03-14*
