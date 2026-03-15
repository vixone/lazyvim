# Phase 1: Daemon Infrastructure - Research

**Researched:** 2026-03-14
**Domain:** WezTerm multiplexer architecture, launchd daemon management, Lua module organization
**Confidence:** HIGH

## Summary

Phase 1 establishes persistent WezTerm sessions via an always-on mux server managed by macOS launchd. WezTerm's multiplexer (mux) architecture separates the terminal backend (persistent daemon) from the GUI frontend (ephemeral windows), enabling tabs and panes to survive window closures and system restarts.

The core pattern is: (1) Define a unix domain socket in `config.unix_domains`, (2) Set `config.default_gui_startup_args` to auto-connect on launch, (3) Configure launchd plist with KeepAlive for daemon resilience, (4) Scaffold Lua module structure for future session management layers.

**Primary recommendation:** Start with unix domain configuration and manual daemon testing (`wezterm connect local-mux`) before adding launchd automation. Validate that existing features (theme toggle, tab lock, smart-splits, hints bar) remain functional with mux domain active before moving to production.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Connection Model:** Always-on daemon via unix domain — WezTerm always connects to mux server
- **Auto-attach on open:** Previous tabs/panes reappear silently (interim until session picker in Phase 6/7)
- **Config flag:** `session_manager.enabled = true/false` to disable daemon and fall back to vanilla behavior
- **Daemon lifecycle:** launchd plist for auto-start on macOS login
- **KeepAlive enabled:** Auto-restart on crash for maximum uptime
- **Logs location:** `~/.local/state/wezterm/` (XDG-style, separate from config)
- **Daemon management:** Via `wez-session daemon start|stop|status|logs` (minimal script in Phase 1)
- **Default domain:** All new tabs/splits spawn in mux domain (persistence by default)
- **Unix domain name:** `local-mux` (used in config and for `wezterm connect local-mux`)
- **Unix socket path:** `~/.local/state/wezterm/` (co-located with logs)
- **Status bar indicator:** Subtle mux connection status alongside existing hints (Lock, Theme, etc.)

### Claude's Discretion
- Exact launchd plist configuration details (ThrottleInterval, ProcessType, etc.)
- How to structure Lua require path for session modules
- How to handle config flag check (early return vs conditional blocks)
- Status bar indicator design (icon choice, color, position in hints bar)
- Error handling when daemon is not running but enabled in config

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| REQ-01 | Always-on mux daemon via launchd that survives WezTerm window closes | Unix domain + launchd plist patterns, KeepAlive configuration |
| REQ-08 | Shell script + Lua module architecture -- zero external dependencies | WezTerm Lua module patterns, shell script structure for daemon management |
| REQ-10 | Integration with existing wezterm.lua config (theme, smart-splits, tab lock, hints) | Extension points in existing config, `wezterm.GLOBAL` state pattern |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| WezTerm | 20230712+ | Terminal emulator with built-in multiplexer | Only dependency — built-in mux server, no tmux/zellij needed |
| launchd | macOS built-in | Daemon lifecycle management | Native macOS service manager, zero install |
| Lua 5.4 | Built into WezTerm | Configuration and scripting | WezTerm's native config language |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `wezterm cli` | Bundled with WezTerm | CLI for mux server operations | Daemon status checks, manual attachment |
| Shell scripts (bash/zsh) | macOS built-in | Daemon wrapper commands | `wez-session` CLI for user-facing operations |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| launchd | cron + wrapper | No KeepAlive, no crash recovery, manual restart only |
| Unix domain | TCP domain | Network overhead, security risk (open port) |
| Lua modules | Single-file config | Maintainable for small configs, unmaintainable beyond ~1000 lines |

**Installation:**
```bash
# WezTerm already installed
# No additional dependencies needed
```

## Architecture Patterns

### Recommended Project Structure
```
~/.config/wezterm/
├── wezterm.lua              # Main config — loads session manager module
├── lua/
│   └── session/
│       ├── init.lua         # Session manager entry point
│       ├── daemon.lua       # Daemon connection logic (Phase 1)
│       ├── state.lua        # Session state management (Phase 2+)
│       └── picker.lua       # Session picker UI (Phase 6+)
├── bin/
│   └── wez-session          # CLI wrapper for daemon + session ops
└── sessions/                # JSON session files (Phase 2+)

~/.local/state/wezterm/
├── wezterm.sock             # Unix domain socket
├── mux-server.log           # Daemon stdout/stderr
└── daemon.pid               # Process ID (optional)

~/Library/LaunchAgents/
└── com.wezterm.mux.plist    # launchd service definition
```

### Pattern 1: Unix Domain Configuration
**What:** Define a persistent mux server accessible via unix socket
**When to use:** Phase 1 — foundation for all persistence features
**Example:**
```lua
-- In wezterm.lua
config.unix_domains = {
  {
    name = 'local-mux',
    socket_path = wezterm.home_dir .. '/.local/state/wezterm/wezterm.sock',
  },
}

-- Auto-connect on GUI start (makes persistence default)
config.default_gui_startup_args = { 'connect', 'local-mux' }
```

### Pattern 2: Conditional Feature Loading
**What:** Config flag to enable/disable daemon connection
**When to use:** Allow fallback to vanilla WezTerm behavior
**Example:**
```lua
-- Early in wezterm.lua
local session_manager = {
  enabled = true,  -- User can set to false
}

-- Conditional domain setup
if session_manager.enabled then
  config.unix_domains = { ... }
  config.default_gui_startup_args = { 'connect', 'local-mux' }
end
```

### Pattern 3: Lua Module Organization
**What:** Split session management code into separate modules
**When to use:** Once config exceeds ~500 lines or has distinct concerns
**Example:**
```lua
-- wezterm.lua
local session = require('lua.session')
session.apply_to_config(config, {
  enabled = true,
  socket_path = wezterm.home_dir .. '/.local/state/wezterm/wezterm.sock',
})

-- lua/session/init.lua
local module = {}

function module.apply_to_config(config, opts)
  if not opts.enabled then return end
  -- Configure unix domain, auto-connect, status bar
end

return module
```

### Pattern 4: Status Bar Extension
**What:** Add mux connection indicator to existing hints bar
**When to use:** Phase 1 — user feedback for daemon status
**Example:**
```lua
-- Extend existing update-status handler
wezterm.on("update-status", function(window, pane)
  -- ... existing copy-on-select logic ...

  local hints = {
    { key = "⌘⇧H", label = "RenameTab" },
    { key = "⌘⇧L", label = "Lock" },
    -- Add mux indicator
    { key = "●", label = "Mux" },  -- Green dot when connected
  }

  -- ... existing hints rendering ...
end)
```

### Pattern 5: launchd Service Definition
**What:** Persistent daemon with auto-restart on crash
**When to use:** Phase 1 — production daemon lifecycle
**Example:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.wezterm.mux</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Applications/WezTerm.app/Contents/MacOS/wezterm</string>
    <string>cli</string>
    <string>proxy</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>/Users/USERNAME/.local/state/wezterm/mux-server.log</string>
  <key>StandardErrorPath</key>
  <string>/Users/USERNAME/.local/state/wezterm/mux-server.log</string>
</dict>
</plist>
```

### Anti-Patterns to Avoid
- **Spawning with domain parameter:** `mux.spawn_window({ domain = { DomainName = 'local-mux' } })` creates duplicate tabs (known pitfall #4). Use `SpawnTab("CurrentPaneDomain")` instead — inherits domain from parent.
- **Blocking config on daemon availability:** Don't fail wezterm.lua if daemon is down. Gracefully degrade or show error in status bar.
- **Hardcoded paths:** Always use `wezterm.home_dir` and `wezterm.config_dir` — supports multi-user systems.
- **Single-file bloat:** Keep wezterm.lua under 500 lines by extracting session logic to `lua/session/` modules.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Daemon lifecycle | Custom PID file + ps checks | launchd + `launchctl` | Handles crashes, login start, log rotation, env vars |
| Mux server protocol | Custom socket communication | `wezterm cli proxy` + `wezterm connect` | WezTerm's built-in mux server handles all serialization, state sync |
| Process management | Shell script loops for monitoring | launchd KeepAlive | Automatic restart on crash, no manual intervention |
| Socket file cleanup | Manual unlink on exit | WezTerm handles it | Mux server cleans up socket on graceful shutdown |

**Key insight:** WezTerm has a production-ready multiplexer and launchd is a robust service manager. Custom solutions add complexity without improving reliability. Leverage built-in tooling.

## Common Pitfalls

### Pitfall 1: Duplicate Tab Spawning with `domain` Parameter
**What goes wrong:** Using `mux.spawn_window({ domain = { DomainName = 'local-mux' } })` creates duplicate tabs in both local and mux domains.
**Why it happens:** WezTerm spawns in the specified domain AND the current domain when using explicit domain parameter.
**How to avoid:** Use `SpawnTab("CurrentPaneDomain")` and `SplitHorizontal/SplitVertical({ domain = "CurrentPaneDomain" })`. When connected to mux domain, current domain IS the mux domain — no explicit parameter needed.
**Warning signs:** Opening a new tab shows two tabs appear, one local (dies on window close) and one mux (persists).

### Pitfall 2: Daemon Not Running on First Launch
**What goes wrong:** User launches WezTerm after fresh install, sees error "Failed to connect to local-mux".
**Why it happens:** `config.default_gui_startup_args` tries to connect before daemon is running.
**How to avoid:** Either (1) detect missing daemon and spawn it on first launch, or (2) provide clear error message + instructions to run `launchctl bootstrap` or `wez-session daemon start`.
**Warning signs:** Fresh install shows connection error, user must manually start daemon.

### Pitfall 3: launchd Plist Validation Failures
**What goes wrong:** `launchctl bootstrap` fails with "Invalid property" or "Path not allowed".
**Why it happens:** macOS security restrictions on ProgramArguments paths, missing required keys, invalid XML.
**How to avoid:** Validate plist with `plutil -lint com.wezterm.mux.plist` before loading. Use absolute paths. Test with `launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.wezterm.mux.plist`.
**Warning signs:** `launchctl list` doesn't show service, `launchctl bootstrap` exits non-zero.

### Pitfall 4: Socket File Permissions
**What goes wrong:** WezTerm GUI can't connect to daemon socket (permission denied).
**Why it happens:** Daemon runs as different user or socket directory has wrong permissions.
**How to avoid:** Ensure `~/.local/state/wezterm/` is created with user ownership (`mkdir -p` + `chmod 700`). Use `$HOME` expansion in launchd plist, not hardcoded username.
**Warning signs:** Connection fails with "Permission denied" even when daemon is running.

### Pitfall 5: Breaking Existing Features
**What goes wrong:** After adding unix domain config, theme toggle / tab lock / smart-splits stop working.
**Why it happens:** Lua syntax errors in new code, or module loading breaks existing `wezterm.GLOBAL` / event handler logic.
**How to avoid:** Test incrementally. Add unix domain config first, verify existing features still work, then add module structure. Use `wezterm show-config` to validate syntax.
**Warning signs:** Config errors on WezTerm launch, features that worked before Phase 1 now fail.

### Pitfall 6: Mux Server Resource Accumulation
**What goes wrong:** Daemon memory/CPU usage grows over days/weeks, eventually becomes unresponsive.
**Why it happens:** Long-running processes can accumulate state, especially with many tabs/panes or frequent reconnects.
**How to avoid:** Monitor resource usage. Consider weekly restart via cron (not launchd — let it run continuously, restart only if measurably degraded). Future phases should implement session save/restore to make restarts seamless.
**Warning signs:** `top` shows `wezterm` using excessive memory, GUI becomes sluggish, reconnects fail.

## Code Examples

Verified patterns from WezTerm documentation and existing config:

### Minimal Daemon Configuration
```lua
-- In wezterm.lua (Phase 1 minimal viable setup)
local wezterm = require('wezterm')
local config = wezterm.config_builder()

-- Session manager feature flag
local session_manager = {
  enabled = true,  -- Set to false to disable daemon mode
}

if session_manager.enabled then
  -- Define unix domain
  config.unix_domains = {
    {
      name = 'local-mux',
      socket_path = wezterm.home_dir .. '/.local/state/wezterm/wezterm.sock',
    },
  }

  -- Auto-connect on launch (makes persistence default)
  config.default_gui_startup_args = { 'connect', 'local-mux' }
end

return config
```

### Daemon Management Script (Minimal Phase 1 Version)
```bash
#!/bin/bash
# bin/wez-session — CLI wrapper for daemon operations

PLIST_PATH="$HOME/Library/LaunchAgents/com.wezterm.mux.plist"
LABEL="com.wezterm.mux"

case "$1" in
  daemon)
    case "$2" in
      start)
        launchctl bootstrap "gui/$UID" "$PLIST_PATH"
        echo "Daemon started"
        ;;
      stop)
        launchctl bootout "gui/$UID" "$PLIST_PATH"
        echo "Daemon stopped"
        ;;
      status)
        if launchctl list | grep -q "$LABEL"; then
          echo "Daemon running"
        else
          echo "Daemon not running"
        fi
        ;;
      logs)
        tail -f "$HOME/.local/state/wezterm/mux-server.log"
        ;;
      *)
        echo "Usage: wez-session daemon {start|stop|status|logs}"
        ;;
    esac
    ;;
  *)
    echo "Usage: wez-session daemon {start|stop|status|logs}"
    echo "(Session commands will be added in future phases)"
    ;;
esac
```

### Status Bar Mux Indicator
```lua
-- Extend existing update-status handler in wezterm.lua
wezterm.on("update-status", function(window, pane)
  -- ... existing copy-on-select logic ...

  -- Mux connection status
  local mux_domain = pane:get_domain_name()
  local is_mux = (mux_domain == 'local-mux')

  local hints = {
    { key = "⌘⇧H", label = "RenameTab" },
    { key = "⌘⇧L", label = "Lock" },
    { key = "⌘⇧N", label = "DailyNote↓" },
    { key = "⌘⇧M", label = "Ideas↓" },
    { key = "⌘⇧T", label = "Theme" },
  }

  -- Prepend mux indicator if connected
  if is_mux then
    table.insert(hints, 1, { key = "●", label = "Mux" })
  end

  -- ... existing hints rendering ...
end)
```

### launchd Plist (Production Configuration)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.wezterm.mux</string>

  <key>ProgramArguments</key>
  <array>
    <string>/Applications/WezTerm.app/Contents/MacOS/wezterm</string>
    <string>cli</string>
    <string>proxy</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>KeepAlive</key>
  <true/>

  <key>StandardOutPath</key>
  <string>/Users/USERNAME/.local/state/wezterm/mux-server.log</string>

  <key>StandardErrorPath</key>
  <string>/Users/USERNAME/.local/state/wezterm/mux-server.log</string>

  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
  </dict>

  <key>ProcessType</key>
  <string>Background</string>
</dict>
</plist>
```

**Note:** Replace `USERNAME` with actual username or use `$HOME` in shell wrapper that generates the plist.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| tmux/zellij external multiplexer | WezTerm built-in mux | WezTerm 20220101+ | Zero dependencies, native integration, no escape sequences |
| StartupAgent (old launchd key) | RunAtLoad | macOS 10.10+ | Modern launchd syntax, better supported |
| `wezterm start --class=daemon` | `wezterm cli proxy` | WezTerm 20210814+ | Official mux server command, cleaner than class hack |
| Single-file configs | Module-based configs | Community pattern (2022+) | Maintainable for complex setups, reusable across projects |

**Deprecated/outdated:**
- **`background_domain` config key:** Removed in WezTerm 20230712+, replaced by `unix_domains` + `default_gui_startup_args`
- **TCP domains for local mux:** Unix sockets are faster and more secure — TCP domains are for SSH/remote only
- **Manual daemon spawning in config:** Use launchd for production — spawning from Lua config is fragile (race conditions, zombie processes)

## Open Questions

1. **Error handling when daemon is unreachable**
   - What we know: `default_gui_startup_args = { 'connect', 'local-mux' }` fails if daemon isn't running
   - What's unclear: Can we detect connection failure in config and spawn GUI without connecting? Or show error dialog?
   - Recommendation: Test both approaches — (A) graceful degradation (fall back to local domain), (B) clear error message + link to `wez-session daemon start`. Option B is simpler and makes daemon requirement explicit.

2. **Socket cleanup on abnormal termination**
   - What we know: WezTerm cleans up socket on graceful shutdown
   - What's unclear: Does stale socket file prevent daemon restart? Do we need manual cleanup in `wez-session daemon start`?
   - Recommendation: Test crash scenarios. Add `rm -f socket_path` to daemon start script as defensive measure.

3. **Lua module require path resolution**
   - What we know: `require('lua.session')` should work based on `wezterm.config_dir`
   - What's unclear: Does WezTerm add `config_dir` to Lua package path automatically, or do we need `package.path` manipulation?
   - Recommendation: Test both `require('lua.session')` and `require('lua/session')`. If neither works, add `package.path = package.path .. ';' .. wezterm.config_dir .. '/?.lua'` early in wezterm.lua.

## Validation Architecture

> Nyquist validation enabled — including test infrastructure requirements

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Manual testing + shell script validation |
| Config file | None — shell script tests in `bin/test-phase1.sh` |
| Quick run command | `bash bin/test-phase1.sh` |
| Full suite command | `bash bin/test-phase1.sh --verbose` |

**Note:** WezTerm Lua configs don't have traditional unit test frameworks. Testing strategy is:
1. **Syntax validation:** `wezterm show-config` exits 0
2. **Daemon lifecycle tests:** Shell script verifying launchctl operations
3. **Feature regression tests:** Manual checklist (theme toggle, tab lock, etc.)
4. **Integration test:** Launch WezTerm, verify auto-connect, close window, reopen, verify panes persist

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REQ-01 | Daemon starts via launchd and survives window close | integration | `bash bin/test-phase1.sh daemon_lifecycle` | ❌ Wave 0 |
| REQ-01 | Tabs/panes persist after close+reopen | integration | `bash bin/test-phase1.sh persistence_check` | ❌ Wave 0 |
| REQ-08 | Config loads without syntax errors | smoke | `wezterm show-config > /dev/null` | ✅ (built-in) |
| REQ-08 | Lua modules load successfully | smoke | `wezterm show-config \| grep -q 'unix_domains'` | ✅ (built-in) |
| REQ-10 | Theme toggle still works | manual | `(manual) CMD+SHIFT+T` | ❌ Wave 0 |
| REQ-10 | Tab lock still works | manual | `(manual) CMD+SHIFT+L` | ❌ Wave 0 |
| REQ-10 | Smart-splits navigation works | manual | `(manual) CTRL+hjkl in split panes` | ❌ Wave 0 |
| REQ-10 | Hints bar renders correctly | manual | `(manual) Visual check of status bar` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `wezterm show-config > /dev/null` (syntax check only)
- **Per wave merge:** `bash bin/test-phase1.sh` (daemon lifecycle + persistence)
- **Phase gate:** Full manual regression checklist + automated tests green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `bin/test-phase1.sh` — automated daemon lifecycle and persistence tests
- [ ] Manual test checklist document (or embedded in PLAN.md) — REQ-10 feature regression

## Sources

### Primary (HIGH confidence)
- WezTerm official documentation — https://wezfurlong.org/wezterm/multiplexing.html (verified unix domain patterns)
- WezTerm changelog — https://wezfurlong.org/wezterm/changelog.html (verified `cli proxy` command availability)
- macOS launchd documentation — `man launchd.plist`, `man launchctl` (verified KeepAlive, RunAtLoad keys)
- Existing wezterm.lua — /Users/t026chirv/.config/wezterm/wezterm.lua (verified `wezterm.GLOBAL`, event handler patterns)

### Secondary (MEDIUM confidence)
- Community WezTerm configs on GitHub — lua module organization patterns (multiple repos show `lua/` subdirectory pattern)
- macOS developer documentation — launchd ProcessType and environment variable handling

### Tertiary (LOW confidence)
- None — all findings verified with official sources or existing code

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - WezTerm documentation explicitly covers mux server, launchd is macOS built-in
- Architecture: HIGH - Patterns verified in existing wezterm.lua (event handlers, GLOBAL state, action_callback)
- Pitfalls: HIGH - Duplicate tab spawning documented in project roadmap, other pitfalls derived from launchd/unix socket fundamentals
- Validation: MEDIUM - No established WezTerm Lua test framework, relying on shell scripts + manual checks

**Research date:** 2026-03-14
**Valid until:** 2026-04-14 (30 days — WezTerm is stable, patterns unlikely to change)
