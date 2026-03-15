# WezTerm Session Manager

## What This Is

A native session management system for WezTerm that provides Zellij-like session capabilities without depending on external terminal multiplexers. It combines WezTerm's built-in mux server, workspaces, and Lua scripting with a shell CLI wrapper to deliver named sessions with layout persistence, fuzzy switching, and command restoration — all portable and git-versioned alongside the WezTerm config.

## Core Value

Users can seamlessly create, switch, save, and restore named terminal sessions — including layout, working directories, and running commands — without leaving WezTerm or installing tmux/zellij.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Always-on mux daemon via launchd that survives WezTerm window closes
- [ ] Named sessions (workspaces) with create, list, switch, and delete operations
- [ ] Layout save/restore: tabs, pane splits, working directories persisted to JSON
- [ ] Running command capture and restoration (e.g., `claude`, `nvim`, `npm dev`)
- [ ] Fuzzy session picker accessible via keybinding for quick switching
- [ ] Session picker on WezTerm launch showing available sessions to restore
- [ ] CLI wrapper (`wez-session`) with subcommands: new, list, attach, save, kill
- [ ] Shell script + Lua module architecture — zero external dependencies
- [ ] Session data stored as JSON files for portability and version control
- [ ] Integration with existing wezterm.lua config (theme, smart-splits, tab lock, hints)

### Out of Scope

- tmux or zellij dependency — the whole point is native WezTerm
- Remote session management (SSH domains) — local only for v1
- Multi-machine session sync — sessions are per-machine, synced via git if desired
- GUI session management app — CLI + in-terminal picker only
- Automatic Claude Code conversation state persistence — we re-launch `claude` in the right CWD, user runs `/resume`

## Context

- Current WezTerm config lives at `~/.config/wezterm/wezterm.lua` — already well-structured with Catppuccin theme (dark/light), smart-splits.nvim integration, tab locking, Zellij-style shortcut hints in the status bar
- WezTerm has a built-in `wezterm-mux-server` binary that can run as a daemon, holding pane state in memory
- WezTerm workspaces provide logical grouping of tabs — switching workspaces hides/shows tab sets
- `wezterm cli` provides programmatic access: `spawn`, `list`, `split-pane`, `set-tab-title`, etc.
- The Lua API exposes `window:active_workspace()`, `panes_with_info()`, `get_current_working_dir()` for introspection
- User runs Claude Code frequently in terminal panes — session restore should re-launch it
- macOS (Darwin) environment — launchd for daemon management

## Constraints

- **Zero dependencies**: Shell script + Lua only — no compiled binaries, no npm, no Python
- **Portability**: Must be fully self-contained in `~/.config/wezterm/` for easy migration between machines
- **Memory**: Lightweight — no background processes beyond the mux server itself
- **Compatibility**: Must not break existing wezterm.lua functionality (theme toggle, tab lock, smart-splits, hints bar)
- **Platform**: macOS primary (launchd), but shell scripts should be adaptable to Linux (systemd)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Shell + Lua over compiled binary | Zero deps, portable, git-versioned, no build step | -- Pending |
| launchd daemon over on-demand mux | Panes truly survive closing WezTerm — Zellij parity | -- Pending |
| JSON for session storage | Human-readable, diffable, version-controllable | -- Pending |
| Fuzzy picker + CLI (both) | Quick switching in-terminal, management from CLI | -- Pending |
| Session picker on launch | User chooses what to restore rather than auto-restoring everything | -- Pending |

---
*Last updated: 2026-03-14 after initialization*
