# Architecture Research

**Domain:** WezTerm Native Session Management
**Researched:** 2026-03-14
**Confidence:** MEDIUM

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    User Interface Layer                      │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │ Shell    │  │ Fuzzy    │  │ On Launch│  │ Key      │    │
│  │ CLI      │  │ Picker   │  │ Picker   │  │ Bindings │    │
│  │ (wez-    │  │ (Lua UI) │  │ (Lua UI) │  │ (Lua)    │    │
│  │ session) │  │          │  │          │  │          │    │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘    │
│       │             │              │             │          │
├───────┴─────────────┴──────────────┴─────────────┴──────────┤
│                   Control Layer (Lua API)                    │
├─────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Session      │  │ Layout       │  │ Workspace    │      │
│  │ Manager      │  │ Serializer   │  │ Controller   │      │
│  │ (Lua Module) │  │ (Lua Module) │  │ (Lua Module) │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                  │                  │              │
│         └──────────────────┴──────────────────┘              │
│                            ↓                                 │
├─────────────────────────────────────────────────────────────┤
│                   WezTerm Mux Server                         │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐        │
│  │ wezterm │  │ Pane    │  │ Tab     │  │ Workspace│        │
│  │   cli   │  │ Manager │  │ Manager │  │ Manager  │        │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘        │
│       │            │            │            │              │
├───────┴────────────┴────────────┴────────────┴──────────────┤
│                   Storage Layer                              │
│  ┌──────────────────────────┐  ┌──────────────────────┐     │
│  │ Session Metadata (JSON)  │  │ launchd plist        │     │
│  │ ~/.config/wezterm/       │  │ ~/Library/Launch-    │     │
│  │   sessions/*.json        │  │   Agents/            │     │
│  └──────────────────────────┘  └──────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| **Shell CLI** | User-facing command interface for session operations | Bash/Zsh script at `~/.config/wezterm/bin/wez-session` with subcommands |
| **Fuzzy Picker** | Interactive session selection UI (keybinding-triggered) | Lua module using `wezterm.action.InputSelector` for quick switching |
| **On Launch Picker** | Session selection on WezTerm startup | Lua module using `wezterm.action.InputSelector` in `gui-startup` event |
| **Session Manager** | Core logic for session CRUD operations | Lua module exposing API: `create()`, `list()`, `attach()`, `save()`, `kill()` |
| **Layout Serializer** | Converts live pane/tab state to/from JSON | Lua module using `wezterm.mux` APIs: `get_tabs()`, `panes_with_info()` |
| **Workspace Controller** | Manages WezTerm workspaces (named session containers) | Lua module wrapping `window:active_workspace()`, `SwitchToWorkspace` |
| **WezTerm Mux Server** | Persistent daemon holding pane state in memory | Native WezTerm binary (`wezterm-mux-server`) managed by launchd |
| **wezterm cli** | Command-line interface for mux operations | Native WezTerm binary: `spawn`, `split-pane`, `list`, `set-tab-title` |
| **Session Metadata** | JSON files storing layout, CWDs, commands per session | JSON files in `~/.config/wezterm/sessions/` (one file per session) |
| **launchd plist** | macOS service definition for always-on mux daemon | XML plist in `~/Library/LaunchAgents/` starting mux server at login |

## Recommended Project Structure

```
~/.config/wezterm/
├── wezterm.lua                # Main config (loads session modules)
├── bin/
│   └── wez-session            # Shell CLI wrapper (create, list, attach, save, kill)
├── lua/
│   └── session/               # Lua modules for session management
│       ├── init.lua           # Module loader and public API
│       ├── manager.lua        # Session CRUD (create, attach, save, delete)
│       ├── serializer.lua     # Layout to/from JSON (panes, tabs, cwds, commands)
│       ├── picker.lua         # Fuzzy picker UI (keybinding-triggered)
│       └── startup.lua        # On-launch session picker
├── sessions/                  # Session storage (git-versioned)
│   ├── default.json           # Default session layout
│   ├── project-foo.json       # Named session: foo
│   └── project-bar.json       # Named session: bar
└── launchd/
    └── com.wezterm.mux.plist  # launchd service definition (copy to ~/Library/LaunchAgents/)
```

### Structure Rationale

- **bin/:** Shell scripts for CLI access from any terminal (added to PATH via shell rc)
- **lua/session/:** Modular Lua code for maintainability. Each module has one responsibility.
- **sessions/:** JSON files for portability. Git-versioned for cross-machine sync. Human-readable for debugging.
- **launchd/:** macOS-specific daemon config. Keeps mux server running independent of GUI windows.

## Architectural Patterns

### Pattern 1: Daemon + CLI Architecture

**What:** Persistent background daemon (mux server) holds live state, CLI tools interact with daemon via IPC.

**When to use:** For terminal multiplexers requiring sessions to survive window closures.

**Trade-offs:**
- **Pro:** True session persistence. Closing GUI doesn't kill panes.
- **Pro:** Lightweight — daemon only uses memory for active panes, no GUI overhead.
- **Con:** Requires daemon management (launchd/systemd). More complex than GUI-only approach.

**Example:**
```bash
# Start daemon via launchd
launchctl load ~/Library/LaunchAgents/com.wezterm.mux.plist

# CLI communicates with daemon via Unix socket
wezterm cli spawn --workspace=my-session

# GUI connects to same daemon (shared pane state)
wezterm connect unix --workspace=my-session
```

### Pattern 2: Workspace as Session Abstraction

**What:** Use WezTerm's built-in workspaces as logical session boundaries. Each workspace = one named session.

**When to use:** For grouping related tabs/panes without custom session implementation.

**Trade-offs:**
- **Pro:** Native WezTerm feature — no custom multiplexing needed.
- **Pro:** Built-in switching via `SwitchToWorkspace` action.
- **Con:** Workspace state is in-memory only. Must layer JSON persistence on top for save/restore.

**Example:**
```lua
-- Lua: Switch to workspace (creates if doesn't exist)
wezterm.action.SwitchToWorkspace({
  name = "project-foo"
})

-- CLI: Spawn tab in specific workspace
wezterm cli spawn --workspace=project-foo --new-window

-- Get current workspace name
local workspace = window:active_workspace()
```

### Pattern 3: JSON Snapshot + Replay

**What:** Serialize live pane/tab state to JSON, restore by replaying commands to recreate layout.

**When to use:** For session persistence across restarts without native save/restore API.

**Trade-offs:**
- **Pro:** Human-readable. Git-versionable. Portable across machines.
- **Con:** Replay is not instant (sequential spawns). Can't restore in-pane state (scrollback, running processes).

**Example JSON Schema:**
```json
{
  "name": "project-foo",
  "workspace": "project-foo",
  "tabs": [
    {
      "title": "editor",
      "panes": [
        {
          "cwd": "/path/to/project",
          "command": "nvim",
          "split": "root"
        },
        {
          "cwd": "/path/to/project",
          "command": null,
          "split": "bottom",
          "percent": 30
        }
      ]
    },
    {
      "title": "server",
      "panes": [
        {
          "cwd": "/path/to/project",
          "command": "npm run dev",
          "split": "root"
        }
      ]
    }
  ]
}
```

**Restore Logic:**
```lua
-- Read JSON
local session = load_session("project-foo.json")

-- Switch to workspace
wezterm.mux.set_active_workspace(session.workspace)

-- Replay tabs and panes
for _, tab_spec in ipairs(session.tabs) do
  local tab = mux.spawn_tab({ cwd = tab_spec.panes[1].cwd })
  tab:set_title(tab_spec.title)

  for i, pane_spec in ipairs(tab_spec.panes) do
    if i > 1 then
      -- Split from first pane
      tab.panes[1]:split({
        direction = pane_spec.split,
        size = { Percent = pane_spec.percent },
        cwd = pane_spec.cwd
      })
    end

    if pane_spec.command then
      -- Send command to pane
      pane:send_text(pane_spec.command .. "\n")
    end
  end
end
```

## Data Flow

### Save Session Flow

```
User runs: wez-session save my-session
    ↓
Shell CLI calls Lua API: session.save("my-session")
    ↓
Session Manager queries current workspace
    ↓
Layout Serializer calls wezterm.mux APIs:
  - mux.get_workspace("my-session")
  - tab:panes_with_info()
  - pane:get_current_working_dir()
  - pane:get_foreground_process_info()
    ↓
Serializer builds JSON structure:
  {name, workspace, tabs[{title, panes[{cwd, command, split}]}]}
    ↓
Write to ~/.config/wezterm/sessions/my-session.json
    ↓
Return: "Session 'my-session' saved"
```

### Restore Session Flow

```
User runs: wez-session attach my-session
    ↓
Shell CLI calls Lua API: session.attach("my-session")
    ↓
Session Manager reads ~/.config/wezterm/sessions/my-session.json
    ↓
Workspace Controller:
  1. Switch to workspace (or create if new)
     wezterm.action.SwitchToWorkspace({name = "my-session"})
    ↓
Layout Serializer replays layout via wezterm cli:
  2. For each tab in JSON:
     - wezterm cli spawn --workspace=my-session --new-window --cwd=/path
     - wezterm cli set-tab-title <title>
  3. For each pane (after first) in tab:
     - wezterm cli split-pane --pane-id=<root> --bottom --cwd=/path
     - If command exists: send_text(command + "\n")
    ↓
Return: "Attached to session 'my-session'"
```

### Fuzzy Picker Flow

```
User presses: CMD+SHIFT+S (session picker keybinding)
    ↓
Lua keybinding triggers: session.picker.show()
    ↓
Picker module:
  1. List available sessions from ~/.config/wezterm/sessions/
  2. Get active workspace name (highlight current)
  3. Build InputSelector choices: [{id, label}]
    ↓
WezTerm shows fuzzy search UI (native InputSelector)
    ↓
User selects session from list
    ↓
Picker calls: session.attach(selected_session)
    ↓
(Same restore flow as above)
```

### Key Data Flows

1. **Session Creation:** User creates session → Lua spawns workspace → CLI spawns initial tab → Save layout JSON
2. **Session Switching:** User triggers picker → Lua lists sessions → User selects → Lua switches workspace (instant if already exists, or restore from JSON if not)
3. **Session Save:** User saves → Lua queries mux → Serialize to JSON → Write to disk
4. **On Launch:** WezTerm starts → `gui-startup` event → Show picker → User selects → Restore session

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| 1-10 sessions | Current architecture sufficient. All sessions in memory if daemon runs. JSON reads are fast (<1ms). |
| 10-50 sessions | Consider session index file (sessions.json) listing all sessions with metadata (name, last_used, description) to avoid scanning directory. |
| 50+ sessions | Add session search/filtering by project type or date. Consider archiving old sessions to `sessions/archive/`. |

### Scaling Priorities

1. **First bottleneck:** Directory listing for picker (50+ JSON files). Fix: Maintain `sessions/index.json` with cached metadata. Update on save/delete.
2. **Second bottleneck:** Session restore time (many tabs/panes). Fix: Parallelize `wezterm cli spawn` calls where possible. Add progress indicator for large sessions.

## Anti-Patterns

### Anti-Pattern 1: Trying to Restore Running Process State

**What people do:** Attempt to serialize and restore exact process state (scrollback, environment variables, interactive shell state).

**Why it's wrong:** WezTerm has no API to capture/restore process memory. Processes must be restarted from scratch.

**Do this instead:** Capture and re-run the *command* that started the process. For interactive tools (nvim, claude), let the tool handle its own state (e.g., nvim sessions, claude `/resume`). Focus on correct CWD and command restoration.

### Anti-Pattern 2: Global Mux Config in wezterm.lua

**What people do:** Hard-code mux server connection settings in `wezterm.lua` thinking it enables persistence.

**Why it's wrong:** Mux server runs independently via launchd. Config file only affects GUI behavior. Hardcoding `default_domain = "unix"` breaks GUI-only workflows.

**Do this instead:** Let CLI tools specify `--prefer-mux` when needed. Keep config file focused on GUI settings. Mux connection happens via CLI flags or environment variables.

### Anti-Pattern 3: Session Data in wezterm.GLOBAL

**What people do:** Store session state in `wezterm.GLOBAL` Lua table (like tab lock example).

**Why it's wrong:** `wezterm.GLOBAL` resets when WezTerm exits. Not suitable for session persistence. Also not accessible from CLI tools.

**Do this instead:** Use JSON files in `~/.config/wezterm/sessions/`. Readable by both Lua (via `io.open`) and shell scripts (via `jq`). Git-versionable for portability.

### Anti-Pattern 4: Synchronous Session Restore in gui-startup

**What people do:** Block `gui-startup` event while restoring large session (many spawns).

**Why it's wrong:** WezTerm GUI hangs until restore completes. Poor UX for large sessions (10+ tabs).

**Do this instead:** Show picker immediately, then restore asynchronously. Or restore in background and show "Restoring session..." tab that updates on completion.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| **launchd** | XML plist defining mux server service | Must copy to `~/Library/LaunchAgents/` and load via `launchctl load`. Daemon starts at login. |
| **Shell RC** | Add `~/.config/wezterm/bin` to PATH | Enables `wez-session` command from any terminal. Add to `~/.zshrc`: `export PATH="$HOME/.config/wezterm/bin:$PATH"` |
| **Git** | Version control for session JSON files | Add `~/.config/wezterm/sessions/*.json` to repo. Ignore `sessions/*.log` if adding debug logs. |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| **Shell CLI ↔ Lua API** | CLI calls `wezterm cli spawn` with Lua script argument | Use `wezterm cli spawn --cwd ~/.config/wezterm -- lua lua/session/manager.lua <action>` pattern. Lua script prints result to stdout, shell captures. |
| **Lua ↔ Mux Server** | Lua uses `wezterm.mux` and `wezterm cli` wrappers | Two modes: In-process (GUI Lua) uses `wezterm.mux.*` directly. Out-of-process (CLI) shells out to `wezterm cli` commands. |
| **Lua ↔ JSON Storage** | Standard Lua `io.open()` and `json.encode()` / `json.decode()` | WezTerm bundles JSON library. Use `local json = require('dkjson')` (or WezTerm's bundled equivalent). |
| **Picker ↔ Session Manager** | Direct Lua function calls within same process | Picker imports session manager module. No IPC needed. |

## Build Order Implications

Suggested implementation order based on component dependencies:

### Phase 1: Daemon Infrastructure
**Components:** launchd plist, mux server startup verification
**Why first:** Foundation for all session persistence. Must be stable before building on top.
**Dependencies:** None
**Deliverable:** `launchd/com.wezterm.mux.plist` + installation script

### Phase 2: Layout Serialization
**Components:** Layout Serializer module (save current state to JSON)
**Why second:** Need save capability before restore. Easier to test (just inspect JSON).
**Dependencies:** Mux server running
**Deliverable:** `lua/session/serializer.lua` with `save_workspace()` function

### Phase 3: Session Manager Core
**Components:** Session Manager module (create, list, save, delete)
**Why third:** Core API that CLI and pickers will use. No UI yet.
**Dependencies:** Serializer
**Deliverable:** `lua/session/manager.lua` with public API

### Phase 4: Shell CLI
**Components:** `bin/wez-session` script with subcommands
**Why fourth:** First user-facing interface. Test session operations without UI complexity.
**Dependencies:** Session Manager
**Deliverable:** `bin/wez-session` (new, list, attach, save, kill)

### Phase 5: Layout Restoration
**Components:** Serializer restore logic (JSON → live panes/tabs)
**Why fifth:** Most complex part. Needs CLI working for testing.
**Dependencies:** Session Manager, Shell CLI
**Deliverable:** `serializer.lua` with `restore_session()` function

### Phase 6: Fuzzy Picker
**Components:** Picker UI (keybinding-triggered session selection)
**Why sixth:** First GUI component. Depends on full save/restore working.
**Dependencies:** Session Manager, Serializer (both save and restore)
**Deliverable:** `lua/session/picker.lua` + keybinding in wezterm.lua

### Phase 7: On-Launch Picker
**Components:** Startup module (show picker on WezTerm launch)
**Why last:** Enhancement to core workflow. Requires picker working.
**Dependencies:** Picker
**Deliverable:** `lua/session/startup.lua` hooked to `gui-startup` event

## Component Communication Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    User Actions                              │
└───┬─────────────────────┬─────────────────────┬─────────────┘
    │                     │                     │
    │ Shell               │ Keybinding          │ Launch
    ↓                     ↓                     ↓
┌───────────┐      ┌──────────────┐      ┌──────────────┐
│ wez-      │      │ Fuzzy Picker │      │ On-Launch    │
│ session   │      │ (Lua)        │      │ Picker (Lua) │
│ (Shell)   │      └──────┬───────┘      └──────┬───────┘
└─────┬─────┘             │                     │
      │                   │                     │
      │ Shells out to     │ Direct call         │ Direct call
      ↓                   ↓                     ↓
┌──────────────────────────────────────────────────────────────┐
│              Session Manager (Lua)                            │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│  │ create() │  │ list()   │  │ attach() │  │ save()   │     │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘     │
│       │             │              │             │           │
│       └─────────────┴──────────────┴─────────────┘           │
│                              ↓                                │
│              Layout Serializer (Lua)                          │
│  ┌────────────────────┐  ┌────────────────────┐              │
│  │ save_workspace()   │  │ restore_session()  │              │
│  └─────────┬──────────┘  └─────────┬──────────┘              │
└────────────┼─────────────────────────┼─────────────────────────┘
             │ queries                 │ replays
             ↓                         ↓
┌──────────────────────────────────────────────────────────────┐
│                   WezTerm Mux Server                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │
│  │ wezterm cli │  │ wezterm.mux │  │ Workspace   │           │
│  │ (IPC)       │  │ (Lua API)   │  │ Manager     │           │
│  └─────────────┘  └─────────────┘  └─────────────┘           │
└──────────────────────────────────────────────────────────────┘
             ↓                         ↑
             │ reads/writes            │
             ↓                         ↑
┌──────────────────────────────────────────────────────────────┐
│                   JSON Storage                                │
│    ~/.config/wezterm/sessions/*.json                          │
└──────────────────────────────────────────────────────────────┘
```

## Research Confidence Assessment

**Overall confidence: MEDIUM**

| Area | Confidence | Reason |
|------|------------|--------|
| WezTerm CLI capabilities | **HIGH** | Verified via `wezterm cli --help`. Commands like `spawn`, `split-pane`, `list`, `set-tab-title` confirmed available. Version 20240203 stable. |
| Workspace abstraction | **HIGH** | Workspaces are documented WezTerm feature. `SwitchToWorkspace` action exists. `window:active_workspace()` API confirmed in existing config. |
| Lua API for mux introspection | **MEDIUM** | `wezterm.mux` exists and provides `get_tabs()`, `panes_with_info()`. Details on `get_foreground_process_info()` not verified — may need fallback to parsing `ps` output. |
| launchd daemon management | **HIGH** | Standard macOS pattern. `wezterm-mux-server` binary exists (confirmed via file checks). launchd plist structure is well-documented. |
| JSON serialization approach | **HIGH** | Standard pattern from tmux-resurrect, zellij layouts. Lua has JSON libraries. Shell can parse with `jq`. |
| Session restore timing | **LOW** | Uncertain how fast `wezterm cli spawn` + `split-pane` sequence is. May need async handling for large sessions (10+ tabs). Needs prototyping. |
| Command capture reliability | **MEDIUM** | `get_foreground_process_info()` API not fully verified. May only get process name, not full command with args. Might need to read `/proc/<pid>/cmdline` equivalent on macOS. |

## Open Questions for Prototyping

1. **Command capture:** Can `get_foreground_process_info()` retrieve full command with arguments, or just process name?
2. **Async restore:** Does `wezterm cli spawn` block? If yes, how to show progress indicator during multi-tab restore?
3. **Workspace switching:** Does `SwitchToWorkspace` to a non-existent workspace create it? Or do we need explicit creation?
4. **Pane IDs:** After `spawn`, how do we get the pane ID for subsequent `split-pane` calls? CLI outputs pane-id to stdout?
5. **GUI-CLI coordination:** If GUI has workspace "foo" open and CLI creates more tabs in "foo", do they appear instantly in GUI? Or need refresh?

## Sources

- WezTerm CLI help output (`wezterm cli --help`, `wezterm cli spawn --help`, `wezterm cli split-pane --help`) — VERIFIED
- WezTerm Lua API knowledge from training data (2025-01 cutoff) — MEDIUM confidence, APIs may have changed
- Existing wezterm.lua config (`~/.config/wezterm/wezterm.lua`) — workspace usage, action_callback patterns — VERIFIED
- Tab lock solution document (`.start/specs/001-wezterm-tab-lock/solution.md`) — Lua patterns, GLOBAL state usage, event handlers — VERIFIED
- Terminal multiplexer architecture patterns (tmux, zellij) from training data — HIGH confidence, established patterns
- macOS launchd documentation from training data — HIGH confidence, stable API

---
*Architecture research for: WezTerm Native Session Management*
*Researched: 2026-03-14*
