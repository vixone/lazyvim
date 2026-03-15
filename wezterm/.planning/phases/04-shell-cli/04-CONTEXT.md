# Phase 4: Shell CLI - Context

**Gathered:** 2026-03-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Extend the existing `bin/wez-session` bash script with session management subcommands (`create`, `list`, `save`, `delete`) that bridge to the Lua `manager.lua` API. The daemon subcommands already exist from Phase 1. Session switching/attaching from JSON is Phase 5 — this phase covers CRUD operations only.

</domain>

<decisions>
## Implementation Decisions

### Command naming
- CRUD verbs: `create`, `list`, `save`, `delete` — explicit and predictable
- No short aliases (no `ls`, `rm`, `new`) — one name per command, less to remember
- No `switch` command — deferred to Phase 5 where `attach` handles both running and saved sessions
- Help text grouped by category: Session commands (create, list, save, delete) and Daemon commands (daemon install/start/...)

### List output format
- Compact aligned table with columns: NAME, STATUS, LAST SAVED
- Current/active session marked with `*` prefix (git branch style)
- Relative timestamps ("2 min ago", "5 hours ago", "3 days ago") — human-friendly
- No `--json` flag for now — table-only for MVP
- No color output — keep it pipe-friendly

### Delete confirmation
- Always prompt "Delete session 'name'? (y/N)" before deleting
- `--force` or `-f` flag to skip confirmation (for scripting)
- When deleting active session, inform user which session was switched to: "Deleted 'project-x'. Switched to 'default'."
- Single session per delete command — no batch deletion
- Friendly error for protected default workspace: "Cannot delete 'default' — it's the fallback workspace."

### Claude's Discretion
- How to bridge bash CLI to Lua manager API (wezterm cli commands, custom event triggers, or direct implementation)
- Error handling patterns and exit codes
- How `save` determines which workspace to save (current vs named argument)
- Help text wording and formatting details
- Any shell portability considerations

</decisions>

<specifics>
## Specific Ideas

- CLI should feel like a single unified tool — daemon commands and session commands under one roof
- CRUD verbs chosen over tmux-style names (`new`/`kill`) for explicitness
- The `*` marker for current session matches `git branch` convention — universally recognized
- Confirmation on delete is safety-first — `--force` provides the escape hatch for automation
- "Cannot delete 'default' — it's the fallback workspace" explains the why, not just the what

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `bin/wez-session`: Already has daemon subcommand group with routing pattern (`case "$1" in ...`), helper functions, and error handling
- `lua/session/manager.lua`: Full CRUD API — `create_session(name)`, `list_sessions()`, `switch_session(name)`, `delete_session(name)`
- `lua/session/state.lua`: `save_current_workspace()`, `load_workspace(name)` — persistence layer
- `bin/test-phase3.sh`: Test pattern for session operations

### Established Patterns
- Bash script with `set -euo pipefail` for safety
- Helper functions for state checks (`is_daemon_loaded`, `is_socket_active`)
- Subcommand routing via nested `case` statements
- Consistent error output to stderr with exit codes
- launchctl-style command structure (verb + noun)

### Integration Points
- `wezterm cli list` — can enumerate panes, tabs, windows from bash
- `wezterm cli spawn --workspace <name>` — can create workspaces from bash
- `wezterm cli send-text` — can send commands to panes
- The existing `main()` routing function needs expansion for session subcommands
- Session JSON files in `~/.config/wezterm/sessions/` — bash can read these directly for list/status

</code_context>

<deferred>
## Deferred Ideas

- `switch`/`attach` command — Phase 5 (needs layout restoration)
- `--json` flag for `list` — add if scripting needs arise
- Short aliases (`ls`, `rm`, `new`) — reconsider if user wants them later
- Batch delete (`delete foo bar baz`) — single only for now

</deferred>

---

*Phase: 04-shell-cli*
*Context gathered: 2026-03-14*
