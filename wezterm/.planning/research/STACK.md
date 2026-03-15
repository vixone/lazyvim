# Stack Research: WezTerm Session Management

**Domain:** Terminal session management (native WezTerm)
**Researched:** 2026-03-14
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| WezTerm Built-in Mux | 20240203+ | Multiplexer daemon for persistent sessions | Native, zero dependencies, designed for this exact use case. Survives GUI window closure when configured as unix domain |
| WezTerm Lua API | Current | Session introspection & management | First-class integration: `wezterm.mux`, `pane:get_current_working_dir()`, `tab:panes_with_info()` provide complete access to session state |
| wezterm cli | Current | Programmatic control from shell | Structured JSON output (`wezterm cli list --format json`), spawn/split-pane/list commands designed for automation |
| Shell Script (bash/zsh) | System default | CLI wrapper & launchd integration | Portable, no compilation needed, can invoke both wezterm cli and Lua callbacks |
| launchd (macOS) | System | Daemon lifecycle management | macOS-native, ensures mux server survives logout, automatic restart on failure |
| JSON (native Lua) | Built-in | Session persistence format | Human-readable, diffable, git-versioned. WezTerm has `wezterm.json_parse()` and `wezterm.json_encode()` built-in (since 20220807) |

### WezTerm CLI Commands

| Command | Purpose | Key Options | Output |
|---------|---------|-------------|--------|
| `wezterm cli spawn` | Create new pane/tab/window | `--workspace`, `--cwd`, `--window-id`, `--new-window` | Pane ID (stdout) |
| `wezterm cli split-pane` | Split existing pane | `--cwd`, `--left/--right/--top/--bottom`, `--percent` | Pane ID (stdout) |
| `wezterm cli list` | Introspect all panes/tabs/windows | `--format json` | JSON array with cwd, title, workspace, size, tty_name, is_active |
| `wezterm cli set-tab-title` | Rename tab | `--tab-id`, title argument | None |
| `wezterm cli rename-workspace` | Rename workspace | Old name, new name arguments | None |
| `wezterm cli activate-pane` | Switch focus to pane | `--pane-id` | None |
| `wezterm cli kill-pane` | Close pane | `--pane-id` | None |
| `wezterm connect` | Attach to unix domain | Domain name, `--workspace` | GUI launches |

**Confidence:** HIGH — Verified with local `wezterm cli --help` (version 20240203) and official GitHub documentation.

### WezTerm Lua API (for Session Introspection)

| API | Purpose | Returns | Since |
|-----|---------|---------|-------|
| `wezterm.mux.spawn_window{}` | Create new window in specific workspace | `(tab, pane, window)` | 20220624 |
| `wezterm.mux.get_active_workspace()` | Get current workspace name | `string` | 20220624 |
| `wezterm.mux.set_active_workspace(name)` | Switch workspace | `nil` (raises error if not exists) | 20220624 |
| `window:active_workspace()` | Get workspace from window object | `string` | 20220319 |
| `tab:panes_with_info()` | Get all panes with layout metadata | `array<{index, is_active, is_zoomed, left, top, width, height, pane}>` | 20220807 |
| `pane:get_current_working_dir()` | Get pane CWD as URI | `Url object` or `nil` | 20240127 (Url object), 20201031 (string) |
| `pane:get_foreground_process_name()` | Get executable path | `string` or `nil` | 20220101 |
| `pane:get_foreground_process_info()` | Get detailed process info | `LocalProcessInfo` or `nil` | 20220624 |
| `pane:split{direction, size}` | Split pane (Lua side) | `pane` | 20220624 |
| `wezterm.json_parse(str)` | Parse JSON | Lua table | 20220807 |
| `wezterm.json_encode(val)` | Encode JSON | JSON string | 20220807 |
| `wezterm.read_dir(path)` | List directory contents | Array of absolute paths | 20200503 |
| `wezterm.run_child_process(args)` | Execute shell command | `(success, stdout, stderr)` | 20200503 |

**Confidence:** HIGH — Verified with official WezTerm GitHub documentation (wez/wezterm main branch).

### WezTerm Events (for Lifecycle Hooks)

| Event | When Triggered | Use Case |
|-------|----------------|----------|
| `mux-startup` | Once when mux server starts | Initialize default workspaces, restore session on daemon launch |
| `gui-startup` | Once when GUI starts (not on `wezterm connect`) | Load session picker, create initial layout |
| `update-right-status` | On every status update | Display active workspace name, locked tabs, current session |

**Confidence:** HIGH — Verified with official GitHub docs.

### Unix Domain Configuration

**Minimal configuration** (in `wezterm.lua`):

```lua
config.unix_domains = {
  {
    name = 'session-mgr',
    -- socket_path defaults to ~/.local/share/wezterm/sock (or platform equivalent)
    -- no_serve_automatically = false (default: will auto-start server)
  },
}

-- Optional: Auto-connect on launch
-- config.default_gui_startup_args = { 'connect', 'session-mgr' }
```

**Why unix domains over default local domain:**
- Panes survive closing all GUI windows
- Can detach/reattach like tmux
- Session state persists until explicit shutdown
- Still runs on macOS/Windows (not just Linux)

**Confidence:** HIGH — Verified with official multiplexing.md docs.

### launchd Configuration (macOS Daemon)

**Plist structure** (`~/Library/LaunchAgents/com.wezterm.mux.plist`):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.wezterm.mux</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/wezterm</string>
        <string>start</string>
        <string>--daemonize</string>
        <string>--domain</string>
        <string>session-mgr</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/wezterm-mux.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/wezterm-mux-error.log</string>
</dict>
</plist>
```

**Control commands:**
```bash
launchctl load ~/Library/LaunchAgents/com.wezterm.mux.plist
launchctl unload ~/Library/LaunchAgents/com.wezterm.mux.plist
launchctl start com.wezterm.mux
launchctl stop com.wezterm.mux
```

**Confidence:** MEDIUM — launchd plist structure is standard macOS, but `--daemonize` flag existence needs verification (may need to use `--no-auto-connect` and rely on unix domain auto-serve instead).

### JSON Session Schema

**Session file location:** `~/.config/wezterm/sessions/<session-name>.json`

**Schema structure:**

```json
{
  "version": "1.0",
  "name": "my-project",
  "workspace": "my-project",
  "created": "2026-03-14T10:30:00Z",
  "last_saved": "2026-03-14T15:45:00Z",
  "tabs": [
    {
      "title": "Editor",
      "active": true,
      "panes": [
        {
          "cwd": "/Users/me/project",
          "command": "nvim",
          "is_active": true,
          "split": null
        }
      ]
    },
    {
      "title": "Terminal",
      "active": false,
      "panes": [
        {
          "cwd": "/Users/me/project",
          "command": null,
          "is_active": false,
          "split": null
        },
        {
          "cwd": "/Users/me/project",
          "command": "npm run dev",
          "is_active": false,
          "split": { "direction": "right", "percent": 50 }
        }
      ]
    }
  ]
}
```

**Rationale:**
- Human-readable for manual editing
- Git-friendly (line-by-line diffs)
- Native Lua support (no external parser)
- Can be exported/shared between machines

**Confidence:** HIGH — JSON handling verified in WezTerm docs, schema is custom design based on available APIs.

### Shell Script Architecture

**File structure:**

```
~/.config/wezterm/
├── wezterm.lua              # Main config
├── session-manager.lua      # Lua module for introspection
├── wez-session              # CLI wrapper (shell script)
├── sessions/                # Session JSON files
│   ├── default.json
│   ├── my-project.json
│   └── work.json
└── .planning/               # Project documentation
```

**CLI wrapper capabilities:**

```bash
wez-session new <name>         # Create new workspace, save empty session
wez-session list               # Show all sessions (from JSON files)
wez-session attach <name>      # Switch to workspace, restore if needed
wez-session save [name]        # Capture current workspace state to JSON
wez-session kill <name>        # Close all panes in workspace, delete session
wez-session picker             # Fuzzy picker via wezterm ShowLauncherArgs
```

**Why shell + Lua, not pure Lua:**
- Shell easier for CLI argument parsing (`getopts`)
- Shell integrates with launchd naturally
- Lua for introspection (via `wezterm.lua` event callbacks)
- Shell invokes `wezterm cli` for actions

**Confidence:** HIGH — Shell scripting is standard practice, Lua module pattern is documented in WezTerm config examples.

## Installation

### Prerequisites

```bash
# WezTerm already installed via Homebrew
which wezterm  # /opt/homebrew/bin/wezterm

# Verify version (needs 20220807+ for panes_with_info, json_parse)
wezterm --version  # wezterm 20240203-110809-5046fc22 ✅
```

### Setup Steps

```bash
# 1. Create session directory
mkdir -p ~/.config/wezterm/sessions

# 2. Add unix_domains to wezterm.lua (see config section above)

# 3. Create launchd plist (optional, for always-on daemon)
# (Copy plist content to ~/Library/LaunchAgents/com.wezterm.mux.plist)

# 4. Load daemon (if using launchd)
launchctl load ~/Library/LaunchAgents/com.wezterm.mux.plist

# 5. Install CLI wrapper (when implemented)
chmod +x ~/.config/wezterm/wez-session
# Optionally symlink to PATH: ln -s ~/.config/wezterm/wez-session /usr/local/bin/
```

**Confidence:** HIGH — Standard installation pattern.

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| WezTerm mux + unix domain | tmux inside WezTerm | If you need cross-terminal compatibility (not WezTerm-specific), or if you already have complex tmux configs |
| WezTerm mux + unix domain | Zellij inside WezTerm | If you prefer Zellij's UI/keybindings and don't mind nested multiplexer overhead |
| WezTerm workspaces | tmux sessions | If you need advanced tmux features like session nesting, or if remoting into machines without WezTerm |
| JSON session files | SQLite database | If you need advanced querying (session history, analytics) — overkill for simple session management |
| Shell + Lua hybrid | Pure Lua | If you're comfortable with Lua CLI arg parsing and want everything in one language — but shell is more familiar for CLI tools |

**Confidence:** HIGH — tmux/Zellij are well-known alternatives, tradeoffs are clear.

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `wezterm start` without unix domain | Panes die when GUI closes, defeating session persistence | Configure unix_domains and use `wezterm connect` |
| Hardcoded socket paths in scripts | Breaks portability (macOS vs Linux), fragile | Let WezTerm use default socket path, or read from config |
| Parsing `wezterm cli list` table output | Fragile, whitespace-dependent, no structure | Use `wezterm cli list --format json` (available since early versions) |
| OSC 7 shell integration for CWD | Not all shells/programs send it, unreliable for restoration | Use it as primary, but fall back to process-based detection (built into `get_current_working_dir()`) |
| Storing full pane scrollback in JSON | Massive file sizes, not portable | Only store metadata (cwd, command, layout). Scrollback lives in mux server memory |
| `--prefer-mux` flag without checking | May connect to wrong instance in multi-user systems | Use `--class` to disambiguate, or rely on unix domain name |

**Confidence:** HIGH — These are common pitfalls based on WezTerm documentation caveats.

## Stack Patterns by Variant

**If targeting Linux (systemd instead of launchd):**
- Use systemd user service (`~/.config/systemd/user/wezterm-mux.service`)
- Enable with: `systemctl --user enable wezterm-mux.service`
- Same WezTerm config otherwise (unix domains work identically)

**If not using daemon (manual session management):**
- Omit launchd/systemd setup
- User manually runs `wezterm connect session-mgr` to start mux server
- Sessions persist until explicit shutdown, but not across reboots
- Good for testing before committing to daemon

**If adding remote session support (future):**
- Add `ssh_domains` to `wezterm.lua` config
- SSH domains auto-populate from `~/.ssh/config` (since 20230408)
- Use `SSHMUX:hostname` prefix to spawn into SSH mux domain
- Session JSON schema gains `domain` field (local vs remote)

**Confidence:** HIGH — Systemd and SSH domains are documented features.

## Version Compatibility

| Feature | Minimum WezTerm Version | Notes |
|---------|-------------------------|-------|
| Unix domains | 20200503+ | Core multiplexing support |
| Workspaces | 20220319+ | `SwitchToWorkspace`, `active_workspace()` |
| `mux-startup` event | 20220624+ | Required for session restoration on daemon start |
| `panes_with_info()` | 20220807+ | Required for layout introspection |
| `json_parse/json_encode` | 20220807+ | Required for JSON session files |
| `get_current_working_dir()` Url object | 20240127+ | Earlier versions return string (still usable) |

**Current user version:** `20240203-110809-5046fc22` — **Compatible** ✅

**Recommendation:** Minimum version `20220807` for full feature set. Earlier versions lack JSON support and `panes_with_info`.

**Confidence:** HIGH — Version gates verified from official docs.

## Process Detection Caveats

**`pane:get_foreground_process_name()` limitations:**

| OS | Support | Mechanism | Caveat |
|----|---------|-----------|--------|
| macOS | ✅ Yes | Process group leader query | Reliable for local panes |
| Linux | ✅ Yes | `/proc/<pid>/` introspection | Reliable for local panes |
| Windows | ✅ Yes | Process tree heuristic | "Most recently spawned descendant" — less reliable |

**Implications for session restoration:**
- Can detect running commands like `nvim`, `claude`, `npm run dev`
- Cannot detect arguments (e.g., `nvim file.txt` vs `nvim other.txt`)
- SSH sessions show `ssh` as process, not remote command
- Multiplexer panes (nested tmux/zellij) don't report process info

**Workaround:** Store intended command in session JSON when saving. On restore, if process detected doesn't match, warn user or skip restoration.

**Confidence:** HIGH — Documented in `get_foreground_process_name.md`.

## Sources

- **WezTerm GitHub Documentation** (https://github.com/wez/wezterm/tree/main/docs) — Official docs for Lua API, CLI commands, multiplexing
  - `docs/multiplexing.md` — Unix domain setup
  - `docs/config/lua/pane/get_current_working_dir.md` — CWD introspection
  - `docs/config/lua/MuxTab/panes_with_info.md` — Layout metadata
  - `docs/config/lua/keyassignment/SwitchToWorkspace.md` — Workspace switching
  - `docs/config/lua/wezterm.mux/spawn_window.md` — Programmatic window creation
  - `docs/cli/cli/spawn.md` — CLI spawn command
  - `docs/cli/cli/split-pane.md` — CLI split command
  - Confidence: **HIGH** — Primary authoritative source

- **Local WezTerm Installation** (`wezterm --version`, `wezterm cli --help`) — Verified installed version (20240203) and available CLI commands
  - Confidence: **HIGH** — Direct verification

- **macOS launchd Documentation** (Apple Developer, `man launchd.plist`) — Standard plist structure for user agents
  - Confidence: **HIGH** — Platform documentation

- **Training Data** (January 2025 knowledge cutoff) — General shell scripting patterns, JSON schema design, systemd service files
  - Confidence: **MEDIUM** — Not WezTerm-specific, but standard practices

---
*Stack research for: WezTerm native session management*
*Researched: 2026-03-14*
*User WezTerm version: 20240203-110809-5046fc22 (verified compatible)*
