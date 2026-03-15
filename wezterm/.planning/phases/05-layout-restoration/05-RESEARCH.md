# Phase 5: Layout Restoration - Research

**Researched:** 2026-03-14
**Domain:** WezTerm session restoration, workspace spawning, pane splitting, command re-execution
**Confidence:** HIGH

## Summary

Phase 5 reconstructs saved sessions from JSON files — recreating tabs, pane splits, working directories, and re-launching processes. This is the restore counterpart to Phase 2's serialization. The core challenge is navigating WezTerm's Lua API limitations (nil process names, no explicit split tree, async CLI ordering) while delivering reliable restoration for common workflows.

The restoration strategy is: (1) Spawn a new workspace window to avoid disrupting existing work (Pitfall #9), (2) Reuse the initial pane for the first saved pane to avoid fragile shell detection (Pitfall #11), (3) Infer split direction from saved geometry (side-by-side → `--right`, stacked → `--bottom`), (4) Accept sequential split approximation for up to 4 panes per tab (Pitfall #2), (5) Re-launch commands using either Lua API `spawn_window/spawn_tab` with args or `wezterm cli spawn` with command args.

**Primary recommendation:** Use Lua API exclusively for restoration logic to avoid CLI command ordering race conditions (Pitfall #3). Implement "smart attach" behavior: if session workspace is running in mux → switch workspace; if only JSON exists → restore from JSON into a new workspace. Accept that complex layouts (5+ panes, nested splits) restore imperfectly — log warnings, don't fail. Focus fidelity on CWD + process restoration for simple layouts (1-4 panes per tab).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Layout reconstruction strategy**: Simple sequential splits — don't try to reconstruct exact split tree
- **Split direction inference**: From saved geometry (panes side-by-side → split-right, panes stacked → split-bottom)
- **Reliable reconstruction**: Up to 4 panes per tab — covers main+side, main+bottom, 2x2 grid
- **Beyond 4 panes**: Best effort with sequential splits + log warning (no user-facing notification)
- **First pane reuse**: First pane in each tab reuses the initial pane (no fragile close-initial-pane logic)
- **Attach behavior**: Smart attach — if session running in mux → switch workspace; if only JSON → restore from JSON into new workspace
- **Restore target**: Always into a new workspace (isolated) — never replaces current workspace tabs/panes
- **Initial pane handling**: First restored pane reuses the initial pane spawned by workspace creation (set its CWD and run its command) — avoids Pitfall #11
- **CLI wiring**: `wez-session attach <name>` CLI subcommand — Lua restore logic in manager.lua, CLI bridge in bin/wez-session
- **Focus**: Always land on first tab, first pane after restore (skip active tab/pane reconstruction)
- **Missing CWD**: Fall back to home directory with log warning (no toast notification)
- **Tab titles**: Restore saved titles from JSON (useful for user-renamed tabs like "Lock:project")
- **Tab order**: Restore tabs in the order they appear in JSON

### Claude's Discretion
- **Command restoration scope**: Which processes to re-launch (shells, nvim, claude, npm dev), how to detect them, what args to pass. JSON captures process basename only, no args
- **Split sizing approach**: Equal splits vs approximate ratios based on WezTerm split-pane API capabilities
- **Async spawn timing**: How to handle CLI command ordering to avoid race conditions (Pitfall #3)
- **Error handling**: For failed pane spawns or split operations
- **Lua vs CLI API mix**: Whether to use Lua API exclusively or mix Lua + CLI for restoration
- **CLI bridge mechanism**: How `attach` subcommand triggers Lua restore API (custom event, wezterm cli commands, or direct implementation)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| REQ-03 | Layout save/restore: tabs, pane splits, working directories persisted to JSON | `wezterm.mux.spawn_window`, `wezterm cli spawn --cwd`, `wezterm cli split-pane --right/--bottom/--cwd`, sequential split pattern for 1-4 panes |
| REQ-04 | Running command capture and restoration (e.g., `claude`, `nvim`, `npm dev`) | `wezterm cli spawn -- <command>`, process detection from JSON, configurable command allowlist pattern |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| WezTerm Lua API | 20240203+ | Workspace creation, pane spawning | Built-in `wezterm.mux.spawn_window`, `wezterm.mux.spawn_tab` for synchronous session creation |
| `wezterm cli` | Bundled | Pane splitting, CWD setting, command execution | `spawn --cwd`, `split-pane --right/--bottom/--cwd`, `set-tab-title` provide precise control |
| Lua `pcall` | Built-in | Error isolation | Graceful degradation for failed pane spawns without crashing restoration |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `wezterm.log_info/warn/error` | Built-in | Diagnostic output | For restoration progress, degraded layout warnings, missing CWD fallbacks |
| `state.load_workspace(name)` | Phase 2 | JSON session loading | Already implemented, returns parsed layout table |
| `state.uri_to_path()` | Phase 2 | CWD path extraction | Reuse for validating saved paths before spawn |
| `manager.list_sessions()` | Phase 3 | Session existence check | Distinguish active vs saved-only sessions for smart attach |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Lua API spawning | CLI-only restoration (shell script) | CLI commands execute out of order (Pitfall #3), requires complex sleep-based synchronization |
| Sequential splits | Exact split tree reconstruction | WezTerm API doesn't expose split tree (Pitfall #2), requires complex geometry inference that fails for nested splits |
| New workspace spawn | Close initial pane + reuse window | Fragile shell detection (Pitfall #11), risk of closing user's active work |
| Configurable process list | Hardcoded nvim/claude/shell only | MVP scope constraint, can extend in v1.1 |

**Installation:**
```bash
# No additional dependencies — all APIs built into WezTerm 20240203+
```

## Architecture Patterns

### Recommended Project Structure
```
lua/session/
├── init.lua         # Entry point
├── daemon.lua       # Daemon connection (Phase 1)
├── state.lua        # Layout serialization (Phase 2)
├── manager.lua      # Session CRUD (Phase 3) + restore_session() ← NEW
└── restore.lua      # Restoration logic (Phase 5) ← NEW (optional split)

bin/
└── wez-session      # CLI wrapper with attach subcommand ← EXTEND
```

### Pattern 1: Smart Attach Behavior
**What:** Attach to existing session workspace OR restore from JSON if not running
**When to use:** Phase 5 — mirrors tmux `attach-session` UX
**Example:**
```lua
-- lua/session/manager.lua
function M.attach_session(name)
  -- Check if workspace is already running
  local running = false
  for _, window in ipairs(wezterm.mux.all_windows()) do
    if window:get_workspace() == name then
      running = true
      break
    end
  end

  if running then
    -- Switch to existing workspace
    return M.switch_session(name)
  else
    -- Restore from JSON
    return M.restore_session(name)
  end
end
```

### Pattern 2: New Workspace Restoration
**What:** Spawn session into a new workspace, never replace current workspace
**When to use:** Phase 5 — avoid Pitfall #9 (data loss from overwriting existing tabs)
**Example:**
```lua
-- lua/session/manager.lua
function M.restore_session(name)
  local layout = state.load_workspace(name)
  if not layout then
    return nil, "Session file not found: " .. name
  end

  -- Auto-save current workspace before switching
  state.save_current_workspace()

  -- Spawn new workspace window
  local tab, pane, window = wezterm.mux.spawn_window({
    workspace = name,
    cwd = wezterm.home_dir,
  })

  if not window then
    return nil, "Failed to create workspace window"
  end

  -- Restore tabs/panes into this new workspace
  M._restore_layout(layout, window, pane)

  wezterm.log_info("Restored session: " .. name)
  return true
end
```

### Pattern 3: First Pane Reuse
**What:** First restored pane reuses the initial pane created by `spawn_window`
**When to use:** Phase 5 — avoid Pitfall #11 (fragile shell detection and initial pane closure)
**Example:**
```lua
-- lua/session/manager.lua (internal helper)
function M._restore_layout(layout, window, initial_pane)
  for tab_idx, tab_data in ipairs(layout.tabs) do
    local target_tab = nil
    local first_pane_in_tab = nil

    if tab_idx == 1 then
      -- Reuse initial tab from spawn_window
      target_tab = window:active_tab()
      first_pane_in_tab = initial_pane
    else
      -- Spawn new tab for subsequent tabs
      target_tab = window:spawn_tab({
        cwd = layout.tabs[tab_idx].panes[1].cwd or wezterm.home_dir,
      })
      first_pane_in_tab = target_tab:active_pane()
    end

    -- Set tab title
    if tab_data.title then
      target_tab:set_title(tab_data.title)
    end

    -- Restore panes in this tab
    M._restore_tab_panes(tab_data, target_tab, first_pane_in_tab)
  end
end
```

### Pattern 4: Sequential Split with Geometry Inference
**What:** Infer split direction from saved pane positions (side-by-side vs stacked)
**When to use:** Phase 5 — reliable for 1-4 panes, best-effort for 5+
**Example:**
```lua
-- lua/session/manager.lua (internal helper)
function M._restore_tab_panes(tab_data, tab, first_pane)
  local panes = tab_data.panes
  if #panes == 0 then return end

  -- First pane: set CWD and optionally spawn command
  M._configure_pane(first_pane, panes[1])

  -- Subsequent panes: split from previous pane
  for i = 2, #panes do
    local prev_pane = panes[i - 1]
    local curr_pane = panes[i]

    -- Infer split direction from geometry
    local direction = "--bottom"  -- default
    if curr_pane.left > prev_pane.left + (prev_pane.width / 2) then
      direction = "--right"
    end

    -- Split and configure
    local new_pane_id = M._split_pane(tab, direction, curr_pane.cwd)
    if new_pane_id then
      -- Optionally spawn command in new pane
      M._spawn_command_in_pane(new_pane_id, curr_pane.process)
    else
      wezterm.log_warn("Failed to create pane " .. i .. " in tab")
    end

    -- Warn if beyond 4 panes (degraded accuracy)
    if i > 4 then
      wezterm.log_warn("Layout restoration accuracy degrades beyond 4 panes per tab")
    end
  end
end

function M._split_pane(tab, direction, cwd)
  -- Use wezterm cli for precise control
  local pane_id_output = wezterm.run_child_process({
    "wezterm", "cli", "split-pane",
    direction,
    "--cwd", cwd or wezterm.home_dir,
  })

  if pane_id_output then
    return tonumber(pane_id_output.stdout:match("%d+"))
  end
  return nil
end
```

### Pattern 5: Selective Process Restoration
**What:** Re-launch known safe processes (shells, nvim, claude), skip others
**When to use:** Phase 5 — address Pitfall #8 (hardcoded process detection)
**Example:**
```lua
-- lua/session/manager.lua (internal helper)
local RESTORABLE_PROCESSES = {
  zsh = true,
  bash = true,
  fish = true,
  nvim = true,
  claude = true,
  ["npm"] = true,  -- Special handling for "npm run dev"
}

function M._configure_pane(pane, pane_data)
  local cwd = pane_data.cwd or wezterm.home_dir
  local process = pane_data.process

  -- Set CWD (if possible via API)
  -- Note: spawn_window already set initial CWD, subsequent panes use split-pane --cwd

  -- Restore process if in allowlist
  if process and RESTORABLE_PROCESSES[process] then
    if process == "nvim" then
      pane:send_text("nvim\n")
    elseif process == "claude" then
      pane:send_text("claude\n")
    elseif process == "npm" then
      -- Guess common dev command
      pane:send_text("npm run dev\n")
    end
    -- Shells spawn by default, no action needed
  else
    -- Log skipped process
    if process and process ~= "zsh" and process ~= "bash" then
      wezterm.log_info("Skipped process restoration: " .. process)
    end
  end
end

function M._spawn_command_in_pane(pane_id, process)
  if not process or not RESTORABLE_PROCESSES[process] then
    return
  end

  -- Use send-text for simplicity
  local command = process
  if process == "npm" then
    command = "npm run dev"
  end

  wezterm.run_child_process({
    "wezterm", "cli", "send-text",
    "--pane-id", tostring(pane_id),
    "--no-paste",
    command .. "\n",
  })
end
```

### Pattern 6: CLI Bridge for Attach Subcommand
**What:** Route `wez-session attach <name>` to Lua restore logic
**When to use:** Phase 5 — enable command-line session restoration
**Example:**
```bash
# bin/wez-session
session_attach() {
    local name="$1"

    if [[ -z "$name" ]]; then
        echo "Error: Session name required. Usage: wez-session attach <name>" >&2
        exit 1
    fi

    ensure_mux_running

    # Trigger Lua restore logic via custom event
    # Option A: Use wezterm cli spawn with Lua snippet
    wezterm cli spawn --workspace "__restore__" -- \
      wezterm -e "lua:require('lua.session.manager').attach_session('${name}')"

    # Option B: Use wezterm cli to trigger a user event
    # (Requires event handler in wezterm.lua)
    # wezterm cli send-text --pane-id 0 \
    #   "wezterm.emit('user-var-changed', 'SESSION_RESTORE', '${name}')\n"

    # Option C: Pure Lua implementation (call manager.attach_session directly)
    # This requires Lua context, so we'd need a helper Lua script
}

case "$1" in
    # ... existing create/list/save/delete ...
    attach)
        session_attach "${2:-}"
        ;;
    # ... rest of main() ...
esac
```

**Better approach (Lua-side):**
```lua
-- wezterm.lua (add keybinding or event handler)
wezterm.on("user-var-changed", function(window, pane, name, value)
  if name == "SESSION_RESTORE" then
    local session = require("lua.session")
    session.manager.attach_session(value)
  end
end)
```

**Simplest approach (direct spawn):**
```bash
# bin/wez-session attach <name>
# Just switch workspace if running, else restore from JSON
session_attach() {
    local name="$1"

    # Check if workspace is running
    local active_workspaces=$(get_active_workspaces)
    if echo "$active_workspaces" | grep -q "^${name}$"; then
        # Already running, switch to it
        wezterm cli spawn --new-window --workspace "$name" >/dev/null 2>&1
        echo "Attached to running session: ${name}"
    else
        # Not running, check if JSON exists
        local json_file="$SESSIONS_DIR/${name}.json"
        if [[ ! -f "$json_file" ]]; then
            echo "Error: Session '${name}' not found (no active workspace, no JSON file)" >&2
            exit 1
        fi

        # Restore from JSON using Lua API
        # Call manager.restore_session() via wezterm evaluate
        # Note: This requires wezterm to support evaluate or lua-eval
        # Fallback: Spawn new workspace and reconstruct manually via CLI
        echo "Restoring session '${name}' from saved state..."
        # TODO: Implement CLI-based restoration or Lua eval bridge
    fi
}
```

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Exact split tree reconstruction | Geometry-to-tree inference algorithm | Sequential splits + direction heuristic | WezTerm API doesn't expose split tree (Pitfall #2), geometry inference fails for nested splits |
| Generic process state serialization | Process memory dump + restore | Allowlist of safe-to-restart processes | Impossible to restore arbitrary process state (open files, history, buffers) — only command re-execution viable |
| CLI command synchronization | Sleep-based delays between commands | Lua API exclusively | CLI commands execute asynchronously (Pitfall #3), race conditions break restoration |
| Initial pane closure | Shell process detection + `exit` command | Spawn new workspace window | Shell detection is fragile (Pitfall #11), misses fish/nu/dash, risks closing running programs |

**Key insight:** WezTerm's Lua API provides synchronous control for workspace/tab creation but not for pane splitting (requires CLI). Mixing Lua and CLI requires careful sequencing. Accept that complex layouts (5+ panes, nested splits) restore imperfectly — log warnings, prioritize CWD + process fidelity over exact geometry.

## Common Pitfalls

### Pitfall 1: `get_foreground_process_name()` Returns Nil for Mux Panes
**What goes wrong:** When calling `pane:get_foreground_process_name()` on multiplexer panes during restoration, the API returns `nil`. Attempting string operations on nil crashes the restore logic.

**Why it happens:** Foreground process detection only works for local panes. Mux domains don't expose process information through the Lua API.

**How to avoid:**
- Always nil-check before using the process field from saved JSON
- Accept that mux panes won't have process restoration
- Use the saved process name from JSON (captured during serialization) instead of querying the pane

**Warning signs:**
- Error: "attempt to index a nil value (local 'process')"
- Process restoration silently fails for mux-based sessions

**Code pattern:**
```lua
-- WRONG
if pane_data.process:find("nvim") then
  -- Crashes if process is nil
end

-- RIGHT
if pane_data.process and pane_data.process:find("nvim") then
  pane:send_text("nvim\n")
end
```

### Pitfall 2: Complex Layouts Restore Incorrectly
**What goes wrong:** Attempting to restore layouts with 5+ panes or nested splits (L-shaped, grid, uneven splits) produces scrambled pane positions. Panes appear in wrong locations or with incorrect sizes.

**Why it happens:** WezTerm's `panes_with_info()` returns pane coordinates but no split tree. Inferring split direction from `left/top/width/height` works for simple side-by-side or stacked panes but fails for complex arrangements.

**How to avoid:**
- Accept reliable restoration only for 1-4 panes per tab
- Use simple heuristic: if `pane.left > prev_pane.left + (prev_pane.width / 2)`, split right; else split bottom
- For 5+ panes: log warning, apply best-effort sequential splits
- Document layout limitations in README

**Warning signs:**
- User reports: "My 6-pane layout looks wrong after restore"
- Panes in different positions than saved
- All splits default to 50/50 even if original was 70/30

**Code pattern:**
```lua
-- Accept degradation for complex layouts
if #panes > 4 then
  wezterm.log_warn("Layout with " .. #panes .. " panes may not restore exactly")
end

-- Simple direction inference
local direction = "--bottom"
if curr_pane.left > prev_pane.left + (prev_pane.width / 2) then
  direction = "--right"
end
```

### Pitfall 3: CLI Commands Execute Out of Order
**What goes wrong:** Running multiple `wezterm cli split-pane` commands in sequence causes splits to target the wrong pane or tab due to async execution.

**Why it happens:** `wezterm cli` communicates with the mux server asynchronously. Commands return immediately without waiting for server completion.

**How to avoid:**
- Use Lua `mux.spawn_window` and `mux.spawn_tab` for workspace/tab creation (synchronous)
- For pane splitting: use CLI but call sequentially within Lua, not in shell script
- Avoid shell-based restoration scripts entirely
- If CLI required: insert barriers (e.g., `wezterm cli list` to confirm state)

**Warning signs:**
- Panes appear in unexpected tabs
- Split operations target wrong pane
- Adding `sleep 0.1` between commands "fixes" the issue

**Code pattern:**
```lua
-- Use Lua for synchronous operations
local tab, pane, window = wezterm.mux.spawn_window({ workspace = name })

-- CLI for splitting (unavoidable), but called from Lua sequentially
for i, pane_data in ipairs(panes) do
  if i > 1 then
    wezterm.run_child_process({ "wezterm", "cli", "split-pane", ... })
    -- Each run_child_process blocks until completion
  end
end
```

### Pitfall 11: Initial Pane Fragile Closure
**What goes wrong:** Restoration logic attempts to close the initial empty pane by detecting if it's running a shell (checks for "sh", "bash", "zsh" in process name) and sending `exit\n`. If detection fails (e.g., fish, nu, dash), the initial pane remains, creating an extra empty tab. If detection incorrectly identifies a running program as a shell, it closes that program.

**Why it happens:** Restoration needs a clean slate. Instead of spawning a new window, some implementations try to reuse the initial window by closing its first pane.

**How to avoid:**
- Spawn restored session into a new workspace window (isolated)
- Reuse the initial pane for the first saved pane (set CWD, spawn command)
- Never send `exit` commands to arbitrary panes
- Avoid shell detection heuristics entirely

**Warning signs:**
- Extra empty tab after restoration
- Running program unexpectedly exits during restore

**Code pattern:**
```lua
-- WRONG: Close initial pane via shell detection
local process = initial_pane:get_foreground_process_name()
if process and process:match("sh$") then
  initial_pane:send_text("exit\n")
end

-- RIGHT: Reuse initial pane for first saved pane
function M.restore_session(name)
  local layout = state.load_workspace(name)
  local tab, initial_pane, window = wezterm.mux.spawn_window({
    workspace = name,
    cwd = layout.tabs[1].panes[1].cwd or wezterm.home_dir,
  })

  -- Configure initial pane with first saved pane's CWD and process
  M._configure_pane(initial_pane, layout.tabs[1].panes[1])

  -- Continue restoring remaining panes via split
  -- ...
end
```

## Code Examples

Verified patterns from Phase 1-4 implementations and WezTerm documentation:

### Workspace Creation with CWD
```lua
-- Source: lua/session/manager.lua (Phase 3)
local tab, pane, window = wezterm.mux.spawn_window({
  workspace = "my-session",
  cwd = "/Users/user/projects/myapp",
})
-- Returns: tab (MuxTab), pane (MuxPane), window (MuxWindow)
```

### Pane Splitting via CLI
```bash
# Source: wezterm cli split-pane --help
# Create right split with specific CWD
wezterm cli split-pane --right --cwd /tmp

# Create bottom split and run command
wezterm cli split-pane --bottom --cwd ~/project -- npm run dev

# Returns pane-id on stdout (e.g., "42")
```

### Tab Title Restoration
```bash
# Source: wezterm cli set-tab-title --help
wezterm cli set-tab-title "Lock:myproject"
```

### Loading Session JSON
```lua
-- Source: lua/session/state.lua (Phase 2)
local state = require("lua.session.state")
local layout = state.load_workspace("my-session")
-- Returns:
-- {
--   version = 1,
--   workspace = "my-session",
--   last_saved = 1710441234,
--   tabs = {
--     {
--       title = "main",
--       active = true,
--       panes = {
--         { index = 0, is_active = true, cwd = "/Users/...", process = "nvim", left = 0, top = 0, width = 80, height = 24 },
--         { index = 1, is_active = false, cwd = "/Users/...", process = "zsh", left = 80, top = 0, width = 40, height = 24 },
--       }
--     }
--   }
-- }
```

### Nil-Safe Process Handling
```lua
-- Source: lua/session/state.lua (Phase 2)
local process = pane:get_foreground_process_name()
if process then
  -- Extract basename (e.g., /bin/zsh -> zsh)
  process = process:match("([^/]+)$") or process
end
-- process may be nil — always check before string operations
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Close initial pane via shell detection | Spawn new workspace window, reuse initial pane for first saved pane | Phase 5 context discussion (2026-03-14) | Avoids Pitfall #11, cleaner isolation |
| CLI-based restoration scripts | Lua API for workspace/tab creation, CLI only for splits | Phase 5 research (Pitfall #3) | Eliminates async ordering issues |
| Exact split tree reconstruction | Sequential splits + direction heuristic | Community consensus (Pitfall #2) | Accepts limitations, focuses on 1-4 pane fidelity |
| Generic process restoration | Allowlist of safe processes (shells, nvim, claude) | Phase 5 context discussion (2026-03-14) | Avoids broken state, user can extend allowlist |

**Deprecated/outdated:**
- `wezterm cli set-working-directory` + `wezterm start` pattern: Ignored at startup (Pitfall #6), use `spawn --cwd` instead
- `mux.spawn_window({ domain = { DomainName = "..." } })`: Creates duplicate tabs (Pitfall #4), omit domain parameter

## Open Questions

1. **Split sizing precision**
   - What we know: CLI `split-pane` supports `--cells <N>` and `--percent <N>` for split sizing
   - What's unclear: Whether saved `width/height` values can be translated to reliable `--percent` values given terminal resize events
   - Recommendation: Start with equal 50/50 splits (MVP), add `--percent` based on saved ratios in v1.1

2. **CLI vs Lua for pane splitting**
   - What we know: Lua API has `mux.spawn_window` and `mux.spawn_tab` but no direct `split_pane` equivalent
   - What's unclear: Whether future WezTerm versions will add Lua pane splitting
   - Recommendation: Use CLI `split-pane` for Phase 5, monitor WezTerm API updates

3. **Process args capture**
   - What we know: Phase 2 JSON only captures process basename (e.g., "nvim"), not full command with args (e.g., "nvim README.md")
   - What's unclear: Whether capturing full command line is feasible or desirable (security, complexity)
   - Recommendation: MVP restores process without args (user manually reopens files), consider args in v1.1 as opt-in feature

4. **Restoration failure handling**
   - What we know: Pane splits can fail (insufficient space, mux errors)
   - What's unclear: Whether to fail entire restoration on first error, or continue with partial restoration + warnings
   - Recommendation: Partial restoration with warnings — user gets most of their session back even if some panes fail

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Bash test suite (bin/test-phase5.sh) |
| Config file | none — see Wave 0 |
| Quick run command | `bin/test-phase5.sh` |
| Full suite command | `bin/test-phase5.sh --verbose` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REQ-03 | Layout save/restore: tabs, panes, CWDs | integration | `bin/test-phase5.sh test_restore_simple_layout` | ❌ Wave 0 |
| REQ-03 | Tab titles restored from JSON | unit | `bin/test-phase5.sh test_tab_titles` | ❌ Wave 0 |
| REQ-03 | First pane reuses initial pane | unit | `bin/test-phase5.sh test_initial_pane_reuse` | ❌ Wave 0 |
| REQ-04 | Process restoration for nvim/claude/shells | integration | `bin/test-phase5.sh test_process_restore` | ❌ Wave 0 |
| REQ-04 | Skipped processes logged | unit | `bin/test-phase5.sh test_process_skip` | ❌ Wave 0 |
| ATTACH | `wez-session attach <name>` switches or restores | integration | `bin/test-phase5.sh test_attach_smart` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `bin/test-phase5.sh` (runs in < 30 seconds)
- **Per wave merge:** `bin/test-phase5.sh --verbose` (full diagnostic output)
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `bin/test-phase5.sh` — covers all REQ-03, REQ-04 behaviors
- [ ] Test helper functions — `setup_test_session()`, `cleanup_test_session()`, `assert_pane_count()`, `assert_tab_title()`
- [ ] Sample test JSON — `sessions/test-session.json` with 2 tabs, 3 panes for validation

## Sources

### Primary (HIGH confidence)
- WezTerm CLI help output (`wezterm cli spawn --help`, `wezterm cli split-pane --help`) — current system, 2026-03-14
- Existing codebase: `lua/session/state.lua`, `lua/session/manager.lua`, `bin/wez-session` — Phase 1-4 patterns verified working
- `.planning/research/PITFALLS.md` — compiled from upstream issues + community session managers
- `.planning/phases/05-layout-restoration/05-CONTEXT.md` — user decisions from discussion phase

### Secondary (MEDIUM confidence)
- danielcopper/wezterm-session-manager — community implementation patterns for layout restoration
- wez/wezterm issues #3237, #3994, #4408, #7368 — confirmed API limitations and bugs

### Tertiary (LOW confidence)
- None — all findings verified with official CLI or existing code

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — All APIs exist and are verified in Phase 1-4
- Architecture: HIGH — Patterns derived from working Phase 3 manager.lua
- Pitfalls: HIGH — Documented from upstream issues and existing implementations
- Process restoration: MEDIUM — Allowlist approach is pragmatic but scope unclear (which processes matter to users?)

**Research date:** 2026-03-14
**Valid until:** 2026-04-14 (30 days, stable domain — WezTerm API unlikely to change significantly)
