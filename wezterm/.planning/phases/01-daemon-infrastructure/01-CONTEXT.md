# Phase 1: Daemon Infrastructure - Context

**Gathered:** 2026-03-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Set up a persistent WezTerm mux server via launchd so that all tabs and panes survive closing the GUI. Scaffold the project directory structure for session management Lua modules. Integrate the unix domain connection into the existing wezterm.lua without breaking theme, tab lock, smart-splits, or hints bar.

</domain>

<decisions>
## Implementation Decisions

### Connection Model
- Always-on daemon connection via unix domain — WezTerm always connects to the mux server
- Auto-attach on WezTerm open — previous tabs/panes reappear silently (interim behavior until session picker exists in Phase 6/7)
- Config flag (`session_manager.enabled = true/false`) to disable daemon connection and fall back to vanilla WezTerm behavior
- When disabled, WezTerm behaves exactly as it does today — zero changes to default workflow

### Daemon Lifecycle
- launchd plist for auto-start on macOS login — daemon always running in background
- KeepAlive enabled for auto-restart on crash — brief interruption but maximizes uptime
- Logs stored at `~/.local/state/wezterm/` — XDG-style, separate from config, won't show in git
- Daemon management via `wez-session daemon start|stop|status|logs` subcommands (CLI wrapper is Phase 4, but Phase 1 should create a minimal script for daemon management)

### Default Domain
- All new tabs (CMD+T) and pane splits (CMD+D, CMD+F) spawn in the mux domain — persistence by default
- Unix domain named `local-mux` — used in config and for `wezterm connect local-mux`
- Unix socket path at `~/.local/state/wezterm/` — co-located with logs, explicit and predictable
- Subtle status bar indicator showing mux connection status alongside existing hints (Lock, Theme, etc.)

### Claude's Discretion
- Exact launchd plist configuration details (ThrottleInterval, ProcessType, etc.)
- How to structure the Lua require path for session modules
- How to handle the config flag check (early return vs conditional blocks)
- Status bar indicator design (icon choice, color, position in hints bar)
- Error handling when daemon is not running but enabled in config

</decisions>

<specifics>
## Specific Ideas

- "I want it to feel like tmux's always-on behavior — persistence is the default, not something you opt into"
- Session picker on launch is the end goal (Phase 6/7), but for Phase 1 auto-attach silently is fine
- The `wez-session` CLI should feel like a single tool for everything session-related, including daemon management
- Domain name `local-mux` chosen for technical clarity

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `wezterm.GLOBAL` — already used for tab lock state, can hold session manager state too
- `wezterm.action_callback` — pattern for custom keybinding actions (used in tab lock, theme toggle)
- `update-status` event handler — already builds a hints bar with theme-aware colors, extend for mux indicator
- Theme system (`themes[mode].hints`) — provides color tokens for status bar elements

### Established Patterns
- Single-file config (`wezterm.lua`) — all config in one file, no module splitting yet
- `wezterm.config_dir` for file paths — used for theme-mode file
- `wezterm.run_child_process` for shell commands — used in clipboard paste
- `toast_notification` for user feedback — used in tab lock
- Keybindings use `CMD|SHIFT` prefix for custom features (L=lock, H=rename, N=notes, M=ideas, T=theme)

### Integration Points
- `config.unix_domains` — where the mux domain definition goes
- `config.default_gui_startup_args` or `gui-startup` event — for auto-connect behavior
- `update-status` handler — extend existing hints bar with mux indicator
- `SpawnTab("CurrentPaneDomain")` and `SplitHorizontal/SplitVertical` — currently use CurrentPaneDomain, should work transparently with mux domain

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-daemon-infrastructure*
*Context gathered: 2026-03-14*
