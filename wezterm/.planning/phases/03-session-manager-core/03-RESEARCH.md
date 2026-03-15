# Phase 3: Session Manager Core - Research

**Researched:** 2026-03-14
**Domain:** WezTerm workspace management, session lifecycle (create/list/switch/delete), Lua API module design
**Confidence:** HIGH

## Summary

Phase 3 creates a Lua API module (`lua/session/manager.lua`) that provides CRUD operations for named sessions (workspaces). This is the control plane — Phase 2 provides state serialization, Phase 3 adds lifecycle management (create/delete workspaces, enumerate sessions, switch between them). Phase 4 (CLI) and Phase 6 (picker) will both consume this API.

The core pattern is: (1) Enumerate sessions by combining running workspaces (`mux.all_windows()` → `window:get_workspace()`) with JSON files (`io.popen("ls sessions/")`), (2) Create sessions via `mux.spawn_window({workspace = name})` with no domain parameter (Pitfall #4), (3) Switch sessions via `window:perform_action(SwitchToWorkspace)`, (4) Delete sessions by removing JSON file and closing all workspace windows.

**Primary recommendation:** Build idempotent operations matching tmux semantics. Create auto-saves current workspace before creating new one (leveraging Phase 2's `save_current_workspace()`), then spawns single empty shell at `~/` in new workspace. List merges active workspaces with saved JSON files, marking status (active/saved). Delete removes JSON and closes workspace, auto-switching to another if deleting active session. Protect 'default' workspace from deletion. Use nil+error-string return pattern for error handling.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Auto-save current workspace before switching** — Session create/switch operations trigger auto-save of current workspace state (zero data loss)
- **Create is idempotent** — If session already exists (running workspace OR JSON file), switch to it instead of erroring (matches `tmux new-session -s name` behavior)
- **New sessions start at home** — Single empty shell pane at `~/` (no optional CWD argument)
- **Session naming strict** — Alphanumeric, dashes, underscores only (matches Phase 2 sanitization pattern)
- **List includes 'default'** — Default workspace is a real session (not hidden)
- **List sorted by last_saved** — Most recent first (natural for session switching)
- **List shows active/saved status** — Distinguish workspace running in mux vs JSON-only
- **Delete does full cleanup** — Remove JSON file AND kill workspace (close all tabs/panes)
- **Active session deletion allowed** — Auto-switch to another session first (most recent, or 'default')
- **Default workspace protected** — Cannot be deleted (prevents accidental loss of base session)
- **No confirmation in API** — Callers (CLI, picker) handle confirmation prompts

### Claude's Discretion
- **Internal API signatures and return types** — Tables, error codes, success booleans
- **How to enumerate active workspaces vs JSON-only sessions** — Combine `mux.all_windows()` with filesystem scan
- **How to kill workspace panes on delete** — Iterate and close, or use workspace API if available
- **Error handling patterns** — Return nil+error string, or boolean+message
- **Whether to add rename operation** — Not in success criteria but may be natural

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| REQ-02 | Named sessions (workspaces) with create, list, switch, and delete operations | WezTerm `mux` API provides `spawn_window({workspace})`, `get_active_workspace()`, `all_windows()` for complete lifecycle control. Lua `io` library enables JSON file enumeration. |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| WezTerm Lua API | 20240203+ | Workspace operations | Built-in `mux.spawn_window()`, `mux.get_active_workspace()`, `mux.all_windows()` provide complete workspace lifecycle control |
| Lua `io` library | Built-in | File enumeration | Standard `io.popen("ls")` or `io.open()` for listing session JSON files |
| Phase 2 `state.lua` | Current | Session serialization | Reuse `save_current_workspace()`, `load_workspace()` for auto-save and metadata extraction |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `wezterm.action.SwitchToWorkspace` | 20220624+ | Workspace switching | For switching to existing workspaces |
| `window:perform_action()` | Built-in | Execute actions | For programmatic workspace switching from Lua |
| `os.remove()` | Built-in | File deletion | For removing session JSON files |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `io.popen("ls")` | `wezterm.read_dir()` | `read_dir()` doesn't exist in WezTerm Lua API; `io.popen()` is standard Lua |
| `mux.spawn_window()` | `SpawnTab` action | `spawn_window()` provides programmatic control and returns objects; actions are for keybindings |
| Manual window closing | WezTerm workspace close API | No direct "close workspace" API exists; must iterate and close windows |

**Installation:**
```bash
# No additional dependencies — all APIs built into WezTerm 20220624+
# User is running 20240203, fully compatible
```

## Architecture Patterns

### Recommended Project Structure
```
~/.config/wezterm/
├── lua/
│   └── session/
│       ├── init.lua         # Entry point (Phase 1)
│       ├── daemon.lua       # Daemon connection (Phase 1)
│       ├── state.lua        # Layout serialization (Phase 2)
│       └── manager.lua      # Session lifecycle (Phase 3) ← NEW
└── sessions/                # JSON session files
    ├── default.json         # Default workspace state
    └── project-x.json       # Named workspace state
```

### Pattern 1: Session Creation (Idempotent)
**What:** Create new named session (workspace), or switch to it if already exists
**When to use:** Phase 3 — primary user-facing operation
**Example:**
```lua
-- lua/session/manager.lua
local wezterm = require("wezterm")
local state = require("lua.session.state")

local M = {}

-- Create or switch to a named session
-- @param name: session name (will be sanitized and validated)
-- @return: true on success, nil + error string on failure
function M.create_session(name)
  -- Validate name
  if not name or name == "" then
    return nil, "Session name cannot be empty"
  end

  if not name:match("^[%w%-_]+$") then
    return nil, "Session name must contain only alphanumeric characters, dashes, and underscores"
  end

  -- Check if session already exists (running or JSON)
  local sessions = M.list_sessions()
  for _, session in ipairs(sessions) do
    if session.name == name then
      -- Already exists, switch to it
      return M.switch_session(name)
    end
  end

  -- Auto-save current workspace before creating new one
  state.save_current_workspace()

  -- Create new workspace
  local mux = wezterm.mux
  local _, _, window = mux.spawn_window({
    workspace = name,
    cwd = wezterm.home_dir,
  })

  if not window then
    return nil, "Failed to create workspace"
  end

  wezterm.log_info("create_session: created session '" .. name .. "'")
  return true
end

return M
```

### Pattern 2: Session Enumeration (Merge Active + Saved)
**What:** List all sessions by combining running workspaces with JSON files
**When to use:** Phase 3 — for list operations, picker UI (Phase 6)
**Example:**
```lua
-- lua/session/manager.lua
function M.list_sessions()
  local mux = wezterm.mux
  local sessions = {}
  local seen = {}

  -- Enumerate active workspaces
  for _, window in ipairs(mux.all_windows()) do
    local workspace = window:get_workspace()
    if workspace and not seen[workspace] then
      seen[workspace] = true
      table.insert(sessions, {
        name = workspace,
        active = true,
        last_saved = nil, -- Will be filled from JSON if exists
      })
    end
  end

  -- Enumerate saved sessions (JSON files)
  local sessions_dir = wezterm.config_dir .. "/sessions"
  local handle = io.popen("ls -1 " .. sessions_dir .. "/*.json 2>/dev/null")
  if handle then
    for filename in handle:lines() do
      local basename = filename:match("([^/]+)%.json$")
      if basename and not seen[basename] then
        seen[basename] = true
        -- Load JSON to get last_saved timestamp
        local layout = state.load_workspace(basename)
        table.insert(sessions, {
          name = basename,
          active = false,
          last_saved = layout and layout.last_saved,
        })
      elseif basename and seen[basename] then
        -- Already in list as active workspace, fill last_saved
        for _, session in ipairs(sessions) do
          if session.name == basename then
            local layout = state.load_workspace(basename)
            session.last_saved = layout and layout.last_saved
            break
          end
        end
      end
    end
    handle:close()
  end

  -- Sort by last_saved (most recent first), then by name
  table.sort(sessions, function(a, b)
    if a.last_saved and b.last_saved then
      return a.last_saved > b.last_saved
    elseif a.last_saved then
      return true
    elseif b.last_saved then
      return false
    else
      return a.name < b.name
    end
  end)

  return sessions
end
```

### Pattern 3: Session Switching
**What:** Activate a different workspace
**When to use:** Phase 3 — switch between existing sessions
**Example:**
```lua
-- lua/session/manager.lua
function M.switch_session(name)
  -- Auto-save current workspace
  state.save_current_workspace()

  -- Switch to target workspace
  -- Note: This must be called from an action callback context
  -- For programmatic use, use mux.set_active_workspace() if available,
  -- or spawn a window in the target workspace to switch to it
  local mux = wezterm.mux

  -- Check if workspace exists
  local exists = false
  for _, window in ipairs(mux.all_windows()) do
    if window:get_workspace() == name then
      exists = true
      break
    end
  end

  if not exists then
    -- Spawn a window to activate the workspace
    local _, _, window = mux.spawn_window({
      workspace = name,
      cwd = wezterm.home_dir,
    })
    if not window then
      return nil, "Failed to switch to workspace"
    end
  end

  -- Focus the workspace (requires action callback context)
  -- This will be called from keybindings/CLI, which provide window/pane context
  return true
end
```

### Pattern 4: Session Deletion
**What:** Remove session JSON and close workspace
**When to use:** Phase 3 — clean up unwanted sessions
**Example:**
```lua
-- lua/session/manager.lua
function M.delete_session(name)
  -- Protect default workspace
  if name == "default" then
    return nil, "Cannot delete default workspace"
  end

  local mux = wezterm.mux
  local current_workspace = mux.get_active_workspace()

  -- If deleting active session, switch to another first
  if name == current_workspace then
    local sessions = M.list_sessions()
    local target = nil

    -- Find most recent session that isn't the one being deleted
    for _, session in ipairs(sessions) do
      if session.name ~= name then
        target = session.name
        break
      end
    end

    -- Fallback to default
    if not target then
      target = "default"
    end

    -- Switch away from session being deleted
    M.switch_session(target)
  end

  -- Remove JSON file
  local sanitized_name = name:gsub("[^%w%-_]", "_")
  local filename = wezterm.config_dir .. "/sessions/" .. sanitized_name .. ".json"
  local ok, err = os.remove(filename)
  if not ok then
    wezterm.log_warn("delete_session: failed to remove JSON file: " .. tostring(err))
    -- Continue anyway to close workspace
  end

  -- Close all windows in the workspace
  for _, window in ipairs(mux.all_windows()) do
    if window:get_workspace() == name then
      -- Close all tabs in the window
      for _, tab in ipairs(window:tabs()) do
        for _, pane in ipairs(tab:panes()) do
          pane:kill()
        end
      end
    end
  end

  wezterm.log_info("delete_session: deleted session '" .. name .. "'")
  return true
end
```

### Anti-Patterns to Avoid
- **Using `mux.spawn_window({ domain = ... })`:** Causes duplicate tab bug (Pitfall #4) — never specify domain parameter
- **Forgetting to auto-save before switching:** Leads to data loss — always call `state.save_current_workspace()` before workspace changes
- **Not protecting 'default':** User can delete base workspace and lose access — always check for "default" name
- **Case-sensitive session names:** WezTerm workspace names are case-sensitive but filesystem may not be (macOS) — use consistent sanitization

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Workspace enumeration | Custom workspace tracking in `wezterm.GLOBAL` | `mux.all_windows()` + `window:get_workspace()` | WezTerm already tracks workspaces; custom tracking gets out of sync |
| Session name validation | Complex regex or external validator | `name:match("^[%w%-_]+$")` | Simple Lua pattern matching is sufficient and matches Phase 2's sanitization |
| Atomic file operations | Custom file locking | Lua `io` + `os.rename()` temp file pattern | Phase 2 already implements atomic writes; reuse pattern |
| Timestamp handling | External date libraries | `os.time()` | Built-in integer timestamps are sufficient and git-friendly (Phase 2 decision) |

**Key insight:** WezTerm mux API provides comprehensive workspace control. The manager layer is thin glue code that combines mux operations with Phase 2's serialization. Don't build custom workspace lifecycle logic — leverage mux API primitives.

## Common Pitfalls

### Pitfall 1: `mux.spawn_window` with `domain` Parameter Creates Duplicate Tabs
**What goes wrong:** Calling `mux.spawn_window({ domain = { DomainName = "local-mux" } })` creates 12-16 empty, unusable tabs (known WezTerm bug #4408)
**Why it happens:** Bug in WezTerm's domain parameter handling for `spawn_window`
**How to avoid:** Never specify `domain` parameter in `spawn_window()`. Spawn in current domain, or switch workspace first and spawn there.
**Warning signs:** Seeing multiple tabs appear when creating one session; tabs have process names but are unresponsive

### Pitfall 2: Session Enumeration Misses JSON-Only or Active-Only Sessions
**What goes wrong:** List only shows running workspaces (missing JSON files), or only shows JSON files (missing active workspaces)
**Why it happens:** Sessions can exist in three states: (1) Active workspace with JSON, (2) Active workspace without JSON (new), (3) JSON file without active workspace (closed)
**How to avoid:** Enumerate both sources (mux windows + JSON files), merge with deduplication, mark status (active/saved)
**Warning signs:** User complains "session disappeared" after closing workspace, or "can't see new session" in list

### Pitfall 3: Forgetting to Auto-Save Before Switching
**What goes wrong:** User switches sessions, loses unsaved state in previous session (new tabs, changed CWDs)
**Why it happens:** Phase 2's auto-save is throttled (2 seconds), may not fire before workspace switch
**How to avoid:** Explicitly call `state.save_current_workspace()` at start of `create_session()` and `switch_session()` operations
**Warning signs:** User reports "lost tabs" or "CWD reset" after switching sessions

### Pitfall 4: Case-Sensitive Workspace Names vs Case-Insensitive Filesystems
**What goes wrong:** User creates sessions "Project" and "project", both map to same JSON file on macOS (case-insensitive HFS+)
**Why it happens:** WezTerm workspace names are case-sensitive, but macOS filesystem is case-insensitive by default
**How to avoid:** Document that session names are case-sensitive on Linux but may conflict on macOS. Consider normalizing to lowercase in future versions.
**Warning signs:** User reports "sessions overwriting each other" on macOS

### Pitfall 5: Deleting Active Session Without Switching First
**What goes wrong:** Deleting current workspace closes all tabs, including the tab running the delete command, leaving user in undefined state
**Why it happens:** Closing panes kills processes synchronously, including CLI or Lua context
**How to avoid:** Always switch to another session before closing windows in deleted session. Check if name == current_workspace at start of `delete_session()`.
**Warning signs:** Delete command hangs or crashes WezTerm

## Code Examples

Verified patterns from existing codebase:

### Workspace Name Sanitization (Reuse from Phase 2)
```lua
-- Source: lua/session/state.lua line 106
local sanitized_name = workspace_name:gsub("[^%w%-_]", "_")
```

### Enumerating Active Workspaces
```lua
-- Source: lua/session/state.lua lines 34-40 (adapted)
local mux = wezterm.mux
local active_workspace = mux.get_active_workspace()
local workspaces = {}

for _, window in ipairs(mux.all_windows()) do
  local ws = window:get_workspace()
  if ws and not workspaces[ws] then
    workspaces[ws] = true
  end
end
```

### Spawning Window in Workspace (Avoiding Pitfall #4)
```lua
-- CORRECT: No domain parameter
local tab, pane, window = mux.spawn_window({
  workspace = "my-session",
  cwd = wezterm.home_dir,
})

-- INCORRECT: Causes duplicate tabs
-- local tab, pane, window = mux.spawn_window({
--   workspace = "my-session",
--   domain = { DomainName = "local-mux" },  -- BUG: creates 12+ tabs
-- })
```

### Auto-Save Current Workspace
```lua
-- Source: lua/session/state.lua lines 96-151
local state = require("lua.session.state")
state.save_current_workspace()  -- Returns true on success, false on error
```

### Loading Session Metadata
```lua
-- Source: lua/session/state.lua lines 156-186
local layout = state.load_workspace("my-session")
if layout then
  local last_saved = layout.last_saved  -- os.time() integer
  local workspace_name = layout.workspace  -- string
  local tabs = layout.tabs  -- array
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual session tracking | WezTerm workspace API | 20220624 (WezTerm) | Workspaces are first-class in WezTerm; no need for custom tracking |
| Single shared workspace | Named workspaces | 20220624 (WezTerm) | Sessions can be completely isolated per project |
| Keybinding-only workspace switching | Programmatic `spawn_window({workspace})` | 20220624 (WezTerm) | Lua code can create/switch sessions without user input |

**Deprecated/outdated:**
- **`wezterm.action.SwitchWorkspaceRelative`:** Exists but requires active workspace context; `spawn_window` is more flexible for programmatic use
- **Manual workspace name storage in `wezterm.GLOBAL`:** Mux API provides authoritative workspace list

## Open Questions

1. **Does `mux.set_active_workspace()` exist for programmatic switching?**
   - What we know: Documentation and existing code uses `spawn_window({workspace})` to switch
   - What's unclear: Whether a direct "set active" API exists without spawning
   - Recommendation: Use `spawn_window` approach (verified to work); document that switching requires window spawn

2. **How to close a workspace without iterating all panes?**
   - What we know: No direct "close workspace" API found in existing code
   - What's unclear: Whether a bulk close operation exists
   - Recommendation: Iterate windows/tabs/panes and call `pane:kill()` (same as CMD+W behavior)

3. **Should session rename be included in Phase 3?**
   - What we know: Not in success criteria or user context
   - What's unclear: Whether it's natural to add while building other CRUD operations
   - Recommendation: Skip for Phase 3 (add in Phase 8 polish if needed)

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Manual testing + shell validation script |
| Config file | None — validation script in `bin/test-phase3.sh` |
| Quick run command | `wezterm --help > /dev/null 2>&1` |
| Full suite command | `bash bin/test-phase3.sh --verbose` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REQ-02 | Create named session | unit | `grep -q "function M.create_session" lua/session/manager.lua` | ❌ Wave 0 |
| REQ-02 | List all sessions | unit | `grep -q "function M.list_sessions" lua/session/manager.lua` | ❌ Wave 0 |
| REQ-02 | Switch to session | unit | `grep -q "function M.switch_session" lua/session/manager.lua` | ❌ Wave 0 |
| REQ-02 | Delete session | unit | `grep -q "function M.delete_session" lua/session/manager.lua` | ❌ Wave 0 |
| REQ-02 | Session name validation | integration | `bash bin/test-phase3.sh` | ❌ Wave 0 |
| REQ-02 | Idempotent create | manual | `(manual) Create session twice, verify no error` | N/A |
| REQ-02 | Active session deletion | manual | `(manual) Delete active session, verify switch` | N/A |
| REQ-02 | Default workspace protection | integration | `bash bin/test-phase3.sh` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `wezterm --help > /dev/null 2>&1`
- **Per wave merge:** `bash bin/test-phase3.sh --verbose`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `bin/test-phase3.sh` — Shell script to validate manager.lua functions exist, name validation works, default protection works
- [ ] `lua/session/manager.lua` — Core module (created in Wave 1)
- [ ] Manual test checklist — REQ-02 feature verification steps embedded in final plan checkpoint task

*(All test infrastructure created in Wave 0)*

## Sources

### Primary (HIGH confidence)
- Existing codebase: `lua/session/state.lua`, `lua/session/daemon.lua`, `lua/session/init.lua` — Established patterns for Lua modules, mux API usage, file I/O
- WezTerm version: 20240203-110809-5046fc22 (user's installed version) — Verified mux API availability
- Phase 2 RESEARCH.md and VERIFICATION.md — Confirmed mux API patterns (`mux.all_windows()`, `mux.get_active_workspace()`, `spawn_window`)
- CONTEXT.md — User decisions on session behavior (idempotent create, auto-save, naming rules)
- ROADMAP.md Pitfall #4 — Documented `spawn_window` domain parameter bug

### Secondary (MEDIUM confidence)
- Phase 1 RESEARCH.md — Domain connection patterns, `wezterm.GLOBAL` usage for state
- Phase 2 state.lua implementation — Atomic file write pattern, sanitization regex

### Tertiary (LOW confidence)
- Training data on WezTerm API — Workspace concepts introduced in 20220624 release
- Lua `io` library patterns — Standard Lua file operations (not WezTerm-specific)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — All APIs verified in existing codebase and user's WezTerm version
- Architecture: HIGH — Patterns directly adapted from Phase 1/2 implementations
- Pitfalls: HIGH — Pitfall #4 documented in ROADMAP, others inferred from mux API behavior

**Research date:** 2026-03-14
**Valid until:** 2026-04-14 (30 days — stable WezTerm API, slow release cadence)
