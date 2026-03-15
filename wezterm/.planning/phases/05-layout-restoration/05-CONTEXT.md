# Phase 5: Layout Restoration - Context

**Gathered:** 2026-03-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Rebuild saved sessions from JSON — recreate tabs, pane splits, working directories, and re-launch commands. This is the restore counterpart to Phase 2's serialization. The `attach` CLI subcommand is added here (deferred from Phase 4). Layout restoration feeds into Phase 6 (fuzzy picker) and Phase 7 (on-launch picker) which will both call the restore API.

</domain>

<decisions>
## Implementation Decisions

### Layout reconstruction strategy
- Simple sequential splits — don't try to reconstruct an exact split tree
- Infer split direction from saved geometry: panes side-by-side → split-right, panes stacked → split-bottom
- Reliable reconstruction for up to 4 panes per tab — covers main+side, main+bottom, 2x2 grid
- Beyond 4 panes: best effort with sequential splits + log warning (no user-facing notification)
- First pane in each tab reuses the initial pane (no fragile close-initial-pane logic)

### Attach behavior
- Smart: if session is running in mux → switch workspace; if only JSON exists → restore from JSON into a new workspace
- Restore always targets a new workspace (isolated) — never replaces current workspace's tabs/panes
- First restored pane reuses the initial pane spawned by workspace creation (set its CWD and run its command) — avoids Pitfall #11 (fragile initial pane closure)
- Wired as `wez-session attach <name>` CLI subcommand — Lua restore logic in manager.lua, CLI bridge in bin/wez-session

### Restoration fidelity
- Split sizing: Claude's discretion (equal splits or approximate original ratios based on WezTerm API support)
- Focus: always land on first tab, first pane after restore (skip active tab/pane reconstruction)
- Missing CWD: fall back to home directory with log warning (no toast notification)
- Tab titles: restore saved titles from JSON (useful for user-renamed tabs like "Lock:project")
- Tab order: restore tabs in the order they appear in JSON

### Claude's Discretion
- Command restoration scope — which processes to re-launch (shells, nvim, claude, npm dev), how to detect them, what args to pass. JSON captures process basename only, no args
- Split sizing approach (equal vs approximate ratios) based on WezTerm split-pane API capabilities
- Async spawn timing — how to handle CLI command ordering to avoid race conditions (Pitfall #3)
- Error handling for failed pane spawns or split operations
- Whether to use Lua API exclusively or mix Lua + CLI for restoration
- How `attach` CLI subcommand bridges to Lua restore API (custom event trigger, wezterm cli commands, or direct implementation)

</decisions>

<specifics>
## Specific Ideas

- "Smart attach" mirrors tmux behavior: `tmux attach-session -t name` attaches if running, creates if not
- First pane reuse avoids the "empty pane" artifact — restoration feels seamless
- 4-pane limit is pragmatic — covers real daily usage without over-engineering geometry inference
- Log warnings (not toasts) for degraded restoration — keeps the experience quiet unless debugging

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lua/session/state.lua`: `load_workspace(name)` — reads and parses session JSON, returns layout table
- `lua/session/state.lua`: `uri_to_path()` — platform-aware path extraction (reuse for CWD validation)
- `lua/session/manager.lua`: `switch_session(name)` — already handles switch-if-running logic, needs extension for restore-if-saved
- `lua/session/manager.lua`: `list_sessions()` — distinguishes active vs saved-only sessions
- `bin/wez-session`: Bash CLI with subcommand routing pattern (`case "$1" in ...`), ready for `attach` subcommand

### Established Patterns
- `wezterm.mux.spawn_window({workspace = name, cwd = ...})` — for creating new workspaces (avoid domain parameter per Pitfall #4)
- Nil-safe patterns from state.lua — check before calling string methods on process/CWD
- Atomic file operations (temp file + rename) in state.lua
- `pcall(require, ...)` for graceful module loading
- `wezterm.log_info/log_warn/log_error` for diagnostic output

### Integration Points
- JSON schema (version 1): `{version, workspace, last_saved, tabs[{title, active, panes[{index, is_active, cwd, process, left, top, width, height}]}]}`
- `wezterm cli spawn --cwd <path>` — for setting pane working directory
- `wezterm cli split-pane --right/--bottom [--cwd <path>]` — for creating splits
- `wezterm cli set-tab-title <title>` — for restoring tab titles
- `manager.lua` needs a new `restore_session(name)` function (or extend `switch_session`)
- `bin/wez-session` needs `attach` subcommand routing to the restore logic

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-layout-restoration*
*Context gathered: 2026-03-14*
