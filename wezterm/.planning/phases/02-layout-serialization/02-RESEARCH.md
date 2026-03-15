# Phase 2: Layout Serialization - Research

**Researched:** 2026-03-14
**Domain:** WezTerm workspace introspection, JSON serialization, event-driven auto-save
**Confidence:** HIGH

## Summary

Phase 2 captures current workspace state (tabs, pane splits, working directories, running processes) to human-readable, git-versionable JSON files. This is the persistence layer — the mux daemon (Phase 1) keeps panes alive in memory, but serialization ensures state survives mux restarts, machine reboots, and enables session portability.

The core pattern is: (1) Hook workspace change events to trigger auto-save, (2) Introspect layout via `mux_window:tabs()` → `tab:panes_with_info()`, (3) Extract CWDs and process names with nil-safe patterns, (4) Encode to JSON with `wezterm.json_encode()`, (5) Write to `sessions/<workspace>.json` using `io.open()`.

**Primary recommendation:** Implement auto-save on workspace changes (tab/pane create/close) by hooking `update-status` event with debouncing. Use one JSON file per workspace to enable clean git diffs. Accept that `get_foreground_process_name()` returns nil for mux panes — nil-check everywhere before string operations. Start with simple nil-safe extraction, defer complex layout reconstruction (Pitfall #2) to Phase 5.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **Auto-save on workspace changes** — Save triggers automatically when tabs open/close or panes split/close (zero user effort)
- **No manual save keybinding** — Auto-save is sufficient for now (can add CMD+SHIFT+S later if needed)
- **Active workspace only** — Save captures the active workspace only, not all workspaces at once (each workspace saves independently when user interacts with it)
- **One JSON file per workspace** — e.g., `sessions/default.json`, `sessions/project-x.json` (clean git diffs, aligns with Phase 3 session naming)

### Claude's Discretion
- **JSON schema structure and field naming** — Must be human-readable and produce clean diffs
- **Layout complexity scope** — Roadmap flags complex nested splits as risky (Pitfall #2), decide MVP scope
- **Process capture depth** — Foreground process name vs full command with args
- **Nil-safe patterns** — For `get_foreground_process_name()` and `get_current_working_dir()` (both can return nil for mux panes)
- **Platform-aware `file:///` URI parsing** — Via `wezterm.target_triple`
- **Auto-save debouncing/throttling strategy** — To avoid excessive writes
- **WezTerm events for auto-save** — What events to hook into for detecting workspace changes

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| REQ-09 | Session data stored as JSON files for portability and version control | `wezterm.json_encode()` built-in since 20220807, `io.open()` for file I/O, one file per workspace pattern |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| WezTerm Lua API | 20240203+ | Layout introspection | Built-in `wezterm.mux`, `tab:panes_with_info()`, `pane:get_current_working_dir()` provide complete session state access |
| `wezterm.json_encode()` | 20220807+ | JSON serialization | Built-in JSON encoder, no external dependencies |
| `wezterm.json_parse()` | 20220807+ | JSON deserialization | Built-in JSON parser for reading session files |
| Lua `io` library | Built-in | File I/O | Standard Lua file operations (`io.open()`, `read()`, `write()`) |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `wezterm.run_child_process` | Built-in | Execute shell commands | For creating directories (`mkdir -p sessions/`) before file writes |
| `wezterm.target_triple` | Built-in | Platform detection | For platform-aware `file:///` URI parsing (Windows vs macOS vs Linux) |
| `wezterm.time` | Built-in | Timestamps | For `last_saved` metadata field in JSON |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Built-in JSON | External `dkjson` library | `wezterm.json_encode()` is simpler and always available since 20220807 |
| `io.open()` | `wezterm.read_dir()` + `wezterm.run_child_process` | `io.open()` is standard Lua, more portable, less overhead |
| Auto-save on events | Manual save keybinding only | User forgets to save, loses state on crashes |

**Installation:**
```bash
# No additional dependencies — all APIs built into WezTerm 20220807+
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
│       └── state.lua        # Layout serialization (Phase 2) ← NEW
└── sessions/                # JSON session files
    ├── default.json         # Default workspace state
    └── project-x.json       # Named workspace state
```

### Pattern 1: Layout Introspection
**What:** Extract current tabs, panes, CWDs, and processes from active workspace
**When to use:** Phase 2 — foundation for all serialization
**Example:**
```lua
-- lua/session/state.lua
local wezterm = require("wezterm")
local mux = wezterm.mux

local M = {}

-- Capture current workspace layout
function M.capture_workspace()
  local workspace = mux.get_active_workspace()
  local tabs = {}

  -- Get all tabs in current workspace
  for _, window in ipairs(mux.all_windows()) do
    if window:get_workspace() == workspace then
      local mux_window = window:mux_window()
      for _, tab in ipairs(mux_window:tabs()) do
        local panes = {}
        for _, pane_info in ipairs(tab:panes_with_info()) do
          local pane = pane_info.pane

          -- Nil-safe CWD extraction
          local cwd = pane:get_current_working_dir()
          local cwd_path = cwd and M.uri_to_path(cwd) or nil

          -- Nil-safe process name extraction
          local process = pane:get_foreground_process_name()
          local process_name = process and process:match("([^/]+)$") or nil

          table.insert(panes, {
            index = pane_info.index,
            is_active = pane_info.is_active,
            cwd = cwd_path,
            process = process_name,
            -- Store layout hints for simple restoration
            left = pane_info.left,
            top = pane_info.top,
            width = pane_info.width,
            height = pane_info.height,
          })
        end

        table.insert(tabs, {
          title = tab:get_title(),
          active = tab:is_active(),
          panes = panes,
        })
      end
    end
  end

  return {
    version = "1.0",
    workspace = workspace,
    last_saved = wezterm.time.now(),
    tabs = tabs,
  }
end

return M
```

### Pattern 2: Nil-Safe API Access
**What:** Defensive nil-checking for WezTerm APIs that return nil for mux panes
**When to use:** Everywhere `get_foreground_process_name()` or `get_current_working_dir()` is called
**Example:**
```lua
-- WRONG: Crashes on mux panes
local process = pane:get_foreground_process_name()
if process:find("nvim") then  -- ERROR: attempt to index nil
  -- ...
end

-- RIGHT: Nil-safe with early exit
local process = pane:get_foreground_process_name()
if process and process:find("nvim") then
  -- ...
end

-- BETTER: Nil-safe with fallback
local process = pane:get_foreground_process_name()
local process_name = process and process:match("([^/]+)$") or "shell"
```

### Pattern 3: Platform-Aware URI Parsing
**What:** Extract filesystem path from `file:///` URIs returned by `get_current_working_dir()`
**When to use:** Phase 2 — normalize paths for cross-platform session files
**Example:**
```lua
-- lua/session/state.lua
function M.uri_to_path(uri_obj)
  if not uri_obj then return nil end

  local uri_str = tostring(uri_obj)
  local target = wezterm.target_triple

  -- Platform-aware path extraction
  if target:find("windows") then
    -- Windows: file:///C:/path/to/dir
    return uri_str:gsub("^file:///", "")
  elseif target:find("darwin") then
    -- macOS: file:///Users/user/path
    return uri_str:gsub("^file://[^/]*/", "/")
  else
    -- Linux: file://{hostname}/home/user/path
    return uri_str:gsub("^file://[^/]*/", "/")
  end
end
```

### Pattern 4: Auto-Save with Debouncing
**What:** Save workspace state on tab/pane changes, but debounce to avoid excessive writes
**When to use:** Phase 2 — automatic persistence without manual triggers
**Example:**
```lua
-- In wezterm.lua or lua/session/init.lua
local save_timer = nil

wezterm.on("update-status", function(window, pane)
  -- Existing copy-on-select and hints bar logic...

  -- Debounced auto-save
  if save_timer then
    save_timer:cancel()
  end

  save_timer = wezterm.time.call_after(2.0, function()  -- 2 second debounce
    local session = require("lua.session")
    session.state.save_current_workspace()
  end)
end)
```

### Pattern 5: JSON Schema for Session Files
**What:** Human-readable, git-diffable JSON structure
**When to use:** Phase 2 — defines contract between save and restore
**Example:**
```json
{
  "version": "1.0",
  "workspace": "default",
  "last_saved": 1710432000,
  "tabs": [
    {
      "title": "Editor",
      "active": true,
      "panes": [
        {
          "index": 0,
          "is_active": true,
          "cwd": "/Users/me/project",
          "process": "nvim",
          "left": 0,
          "top": 0,
          "width": 100,
          "height": 50
        },
        {
          "index": 1,
          "is_active": false,
          "cwd": "/Users/me/project",
          "process": "zsh",
          "left": 0,
          "top": 50,
          "width": 100,
          "height": 50
        }
      ]
    }
  ]
}
```

### Pattern 6: File I/O with Directory Creation
**What:** Write JSON to `sessions/` directory, creating it if needed
**When to use:** Phase 2 — safe file writes without manual directory setup
**Example:**
```lua
-- lua/session/state.lua
function M.save_current_workspace()
  local layout = M.capture_workspace()
  local workspace = layout.workspace
  local filename = wezterm.config_dir .. "/sessions/" .. workspace .. ".json"

  -- Ensure sessions/ directory exists
  local sessions_dir = wezterm.config_dir .. "/sessions"
  wezterm.run_child_process({ "mkdir", "-p", sessions_dir })

  -- Write JSON atomically (write to temp, rename)
  local temp_file = filename .. ".tmp"
  local f = io.open(temp_file, "w")
  if not f then
    wezterm.log_error("Failed to open session file: " .. temp_file)
    return false
  end

  local json = wezterm.json_encode(layout)
  f:write(json)
  f:close()

  -- Atomic rename
  os.rename(temp_file, filename)

  wezterm.log_info("Saved workspace '" .. workspace .. "' to " .. filename)
  return true
end
```

### Anti-Patterns to Avoid
- **No nil-checking before string methods:** Always check `if value then` before calling `value:find()`, `value:match()`, etc.
- **Hardcoded platform paths:** Use `wezterm.target_triple` for platform detection, not manual OS checks
- **Saving on every keystroke:** Debounce auto-save to avoid disk thrashing (2-5 second delay)
- **Blocking file I/O:** File writes should be fast (<10ms for typical sessions), but consider error handling for full disks
- **Complex layout reconstruction:** Accept that Phase 2 only captures coordinates, not split tree (defer reconstruction to Phase 5)

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON encoding | Custom Lua table serializer | `wezterm.json_encode()` | Built-in since 20220807, handles edge cases (special chars, nested tables) |
| File locking | Custom lock files | Atomic `os.rename()` | Unix guarantees atomic renames, prevents partial writes |
| Debouncing | Manual timestamp tracking | `wezterm.time.call_after()` | Timer cancellation built-in, cleaner API |
| URI parsing | Regex from scratch | Platform detection + `gsub()` patterns | Cross-platform URIs are complex, use verified patterns |

**Key insight:** WezTerm's Lua API is feature-complete for this domain. The hard parts (JSON encoding, timer management, layout introspection) are already built-in. Focus effort on nil-safe patterns and clean schema design, not infrastructure.

## Common Pitfalls

### Pitfall 1: `get_foreground_process_name()` Returns nil for Mux Panes
**What goes wrong:** Calling `pane:get_foreground_process_name()` on multiplexer domain panes returns `nil` instead of process name. Attempting string methods (`:find()`, `:match()`) on nil crashes with "attempt to index a nil value."

**Why it happens:** Foreground process detection only works for local panes. Mux and SSH domains don't expose process information through the Lua API.

**How to avoid:**
1. Always nil-check before string operations: `if process then process:match(...) end`
2. Provide sensible fallback: `local name = process and process:match("([^/]+)$") or nil`
3. Store nil as-is in JSON (JSON `null`), don't try to detect processes for mux panes
4. Document in README that process restoration only works for local domains

**Warning signs:**
- Error logs: "attempt to index a nil value (local 'foreground_process')"
- Session save succeeds but process field is missing/wrong for some panes
- Works in local domain, breaks after Phase 1 enables mux domain

### Pitfall 2: Complex Pane Layouts Cannot Be Reliably Reconstructed
**What goes wrong:** `panes_with_info()` returns coordinates (`left`, `top`, `width`, `height`) but no explicit split tree. Restoring L-shaped layouts or 3+ nested splits produces wrong geometry.

**Why it happens:** The API exposes final rendered positions, not the sequence of split operations. Reconstructing split tree from coordinates is ambiguous (multiple split sequences produce same layout).

**How to avoid:**
1. Accept limitation: Phase 2 captures coordinates for Phase 5 to attempt restoration
2. Store layout hints (`left == prev_left` → vertical split, `top == prev_top` → horizontal split)
3. Document that complex layouts may restore differently
4. For MVP: Focus on capturing accurate state, defer reconstruction concerns to Phase 5

**Warning signs:**
- Users report: "My layout looks scrambled after restore"
- Panes in different positions relative to each other
- Split percentages reset to 50/50

### Pitfall 3: Auto-Save Without Debouncing Thrashes Disk
**What goes wrong:** Hooking `update-status` event without debouncing causes saves on every keystroke, resulting in hundreds of writes per minute.

**Why it happens:** `update-status` fires on every pane activity (keypress, output, cursor move). Direct save triggers write immediately.

**How to avoid:**
1. Use `wezterm.time.call_after(delay, callback)` to schedule saves
2. Cancel previous timer before scheduling new one (debounce pattern)
3. Use 2-5 second delay (balances responsiveness vs disk I/O)
4. Log save operations during testing to measure frequency

**Warning signs:**
- High disk I/O in Activity Monitor when typing
- `sessions/` directory shows many rapid timestamp updates
- System feels sluggish during terminal use

### Pitfall 4: `file:///` URI Parsing Breaks Cross-Platform
**What goes wrong:** `get_current_working_dir()` returns different URI formats per OS: `file:///C:/path` (Windows), `file:///Users/path` (macOS), `file://{hostname}/home/path` (Linux). Naive `gsub("file:///", "")` breaks on Linux and macOS.

**Why it happens:** OS-specific file URI conventions. Windows uses drive letters, Linux includes hostname, macOS has simpler format.

**How to avoid:**
1. Use `wezterm.target_triple` to detect platform
2. Apply platform-specific `gsub()` patterns (see Pattern 3 above)
3. Test on all three platforms before release
4. Consider normalizing to Unix-style paths in JSON (convert on save/restore)

**Warning signs:**
- Panes spawn in wrong directory after restore
- Path includes `file://` prefix or hostname
- Works on dev machine, breaks on user's different OS

### Pitfall 5: Partial Writes Corrupt Session Files
**What goes wrong:** WezTerm crashes or system loses power during `f:write(json)`, leaving partially written or empty JSON file. Next launch fails to parse session.

**Why it happens:** File writes are buffered and not atomic. Crash between `write()` and `close()` leaves incomplete data.

**How to avoid:**
1. Write to temporary file (`filename.tmp`), then `os.rename()` to final name
2. Unix guarantees atomic renames (old file replaced in single operation)
3. Keep previous session file intact until new one is verified
4. Add `version` field to JSON for forward compatibility

**Warning signs:**
- Truncated JSON files in `sessions/`
- JSON parse errors on startup after crash
- Missing session data after abnormal termination

### Pitfall 6: Empty Workspace Produces Unusable Session Files
**What goes wrong:** Saving a workspace with zero tabs produces JSON with empty `tabs` array. Restoring attempts to recreate nothing, leaving user with blank terminal.

**Why it happens:** User closes all tabs in a workspace before auto-save triggers, or uses `--new-window` flag without existing tabs.

**How to avoid:**
1. Skip save if `tabs` array is empty
2. Log warning: "Workspace has no tabs, skipping save"
3. Alternative: Save with `tabs: []` and handle gracefully in restore (spawn default shell)
4. Document that empty workspaces are not persisted

**Warning signs:**
- Session file exists but restore does nothing
- User expects tabs to reappear, sees blank terminal
- `tabs: []` in JSON file

## Code Examples

Verified patterns from existing codebase and WezTerm documentation:

### Minimal State Module (lua/session/state.lua)
```lua
-- lua/session/state.lua
local wezterm = require("wezterm")
local mux = wezterm.mux

local M = {}

-- Platform-aware URI to path conversion
function M.uri_to_path(uri_obj)
  if not uri_obj then return nil end

  local uri_str = tostring(uri_obj)
  local target = wezterm.target_triple

  if target:find("windows") then
    return uri_str:gsub("^file:///", "")
  elseif target:find("darwin") then
    return uri_str:gsub("^file://[^/]*/", "/")
  else
    return uri_str:gsub("^file://[^/]*/", "/")
  end
end

-- Capture current workspace layout
function M.capture_workspace()
  local workspace = mux.get_active_workspace()
  local tabs = {}

  for _, window in ipairs(mux.all_windows()) do
    if window:get_workspace() == workspace then
      local mux_window = window:mux_window()
      for _, tab in ipairs(mux_window:tabs()) do
        local panes = {}
        for _, pane_info in ipairs(tab:panes_with_info()) do
          local pane = pane_info.pane

          -- Nil-safe extractions
          local cwd = pane:get_current_working_dir()
          local process = pane:get_foreground_process_name()

          table.insert(panes, {
            index = pane_info.index,
            is_active = pane_info.is_active,
            cwd = cwd and M.uri_to_path(cwd) or nil,
            process = process and process:match("([^/]+)$") or nil,
            left = pane_info.left,
            top = pane_info.top,
            width = pane_info.width,
            height = pane_info.height,
          })
        end

        table.insert(tabs, {
          title = tab:get_title(),
          active = tab:is_active(),
          panes = panes,
        })
      end
    end
  end

  return {
    version = "1.0",
    workspace = workspace,
    last_saved = wezterm.time.now(),
    tabs = tabs,
  }
end

-- Save current workspace to JSON
function M.save_current_workspace()
  local layout = M.capture_workspace()

  -- Skip if no tabs (empty workspace)
  if #layout.tabs == 0 then
    wezterm.log_warn("Workspace '" .. layout.workspace .. "' has no tabs, skipping save")
    return false
  end

  local workspace = layout.workspace
  local sessions_dir = wezterm.config_dir .. "/sessions"
  local filename = sessions_dir .. "/" .. workspace .. ".json"
  local temp_file = filename .. ".tmp"

  -- Ensure sessions/ directory exists
  wezterm.run_child_process({ "mkdir", "-p", sessions_dir })

  -- Write to temp file
  local f = io.open(temp_file, "w")
  if not f then
    wezterm.log_error("Failed to open session file: " .. temp_file)
    return false
  end

  local json = wezterm.json_encode(layout)
  f:write(json)
  f:close()

  -- Atomic rename
  os.rename(temp_file, filename)

  wezterm.log_info("Saved workspace '" .. workspace .. "' to " .. filename)
  return true
end

return M
```

### Auto-Save with Debouncing (in wezterm.lua)
```lua
-- In wezterm.lua
local session = require("lua.session")
local save_timer = nil

wezterm.on("update-status", function(window, pane)
  -- Existing copy-on-select logic...
  local sel = window:get_selection_text_for_pane(pane)
  if sel and sel ~= "" then
    window:copy_to_clipboard(sel, "Clipboard")
  end

  -- Debounced auto-save (2 second delay)
  if save_timer then
    save_timer:cancel()
  end

  save_timer = wezterm.time.call_after(2.0, function()
    session.state.save_current_workspace()
  end)

  -- Existing hints bar logic...
  local mux_connected = session.daemon.is_connected(pane)
  local hints = {
    { key = "⌘⇧H", label = "RenameTab" },
    { key = "⌘⇧L", label = "Lock" },
    { key = "⌘⇧N", label = "DailyNote↓" },
    { key = "⌘⇧M", label = "Ideas↓" },
    { key = "⌘⇧T", label = "Theme" },
  }

  if mux_connected then
    table.insert(hints, 1, { key = "\u{f0ac}", label = "Mux" })
  end

  -- Render hints...
end)
```

### Module Integration (in lua/session/init.lua)
```lua
-- lua/session/init.lua
local wezterm = require("wezterm")
local daemon = require("lua.session.daemon")
local state = require("lua.session.state")

local M = {}

-- Expose submodules
M.daemon = daemon
M.state = state

-- Apply session configuration
function M.apply_to_config(config, opts)
  opts = opts or { enabled = true }

  if not opts.enabled then
    return
  end

  -- Configure unix domain for mux server (Phase 1)
  config.unix_domains = daemon.get_unix_domain_config()
  config.default_gui_startup_args = daemon.get_startup_args()

  -- Phase 2: Auto-save setup will be triggered by update-status in wezterm.lua
  -- (no config changes needed here)
end

return M
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual session save commands | Auto-save on workspace changes | Community pattern (2023+) | Zero user effort, no data loss from forgetting to save |
| Custom JSON encoder | `wezterm.json_encode()` | WezTerm 20220807+ | Simpler code, no external dependencies, proper Unicode handling |
| String paths in API | `Url` objects for CWDs | WezTerm 20240127+ | Type safety, but requires `tostring()` for serialization |
| `update-right-status` for events | `update-status` | WezTerm 20220319+ | Single event handler for all status updates |

**Deprecated/outdated:**
- **`get_current_working_dir()` returning plain strings:** Now returns `Url` objects (since 20240127). Use `tostring(uri)` before parsing.
- **Manual timer management:** `wezterm.time.call_after()` handles cleanup automatically (cancelling timers on event re-trigger).
- **Storing session state in `wezterm.GLOBAL`:** Not persistent across restarts. Use JSON files in `sessions/` directory.

## Open Questions

1. **Optimal debounce delay for auto-save**
   - What we know: 2 seconds balances responsiveness vs disk I/O
   - What's unclear: Should delay scale with session size? (More tabs = longer delay?)
   - Recommendation: Start with fixed 2 seconds. Add telemetry in testing to measure save frequency and adjust if needed.

2. **Session file versioning strategy**
   - What we know: `version: "1.0"` field allows future schema changes
   - What's unclear: How to handle forward/backward compatibility? (Old WezTerm reads new schema, or vice versa)
   - Recommendation: For Phase 2, only write v1.0. Add version check in Phase 5 restore logic. Document breaking changes in CHANGELOG.

3. **Handling workspaces with no name (default)**
   - What we know: `mux.get_active_workspace()` returns "default" if no workspace set
   - What's unclear: Should default workspace be saved, or only named workspaces?
   - Recommendation: Save all workspaces including "default". User always has a session file to restore from.

## Validation Architecture

> Nyquist validation enabled — including test infrastructure requirements

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Manual testing + Lua validation script |
| Config file | None — validation script in `bin/test-phase2.lua` |
| Quick run command | `wezterm cli spawn -- lua bin/test-phase2.lua` |
| Full suite command | `bash bin/test-phase2.sh --verbose` |

**Note:** WezTerm Lua configs don't have traditional unit test frameworks. Testing strategy:
1. **Syntax validation:** `wezterm show-config` exits 0
2. **Module loading test:** `require('lua.session.state')` succeeds
3. **Capture test:** Create test layout, call `capture_workspace()`, verify JSON structure
4. **Nil-safety test:** Force mux pane scenario, verify no crashes on `get_foreground_process_name()`
5. **File I/O test:** Save session, verify file exists and is valid JSON
6. **Manual verification:** User creates multi-tab layout, checks `sessions/default.json` content

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REQ-09 | Workspace state saved to JSON file | integration | `lua bin/test-phase2.lua capture_test` | ❌ Wave 0 |
| REQ-09 | JSON file is valid and parseable | unit | `wezterm cli spawn -- lua -e "wezterm.json_parse(io.open('sessions/default.json'):read('*a'))"` | ✅ (built-in) |
| REQ-09 | One file per workspace (clean diffs) | manual | `(manual) Create two workspaces, verify two JSON files` | ❌ Wave 0 |
| REQ-09 | CWDs captured correctly | integration | `lua bin/test-phase2.lua cwd_test` | ❌ Wave 0 |
| REQ-09 | Process names captured (nil-safe) | integration | `lua bin/test-phase2.lua process_test` | ❌ Wave 0 |
| REQ-09 | Auto-save triggers on workspace changes | manual | `(manual) Open/close tab, verify JSON updated` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `wezterm show-config > /dev/null` (syntax check only)
- **Per wave merge:** `bash bin/test-phase2.sh` (capture + file I/O tests)
- **Phase gate:** Full manual regression checklist + automated tests green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `bin/test-phase2.lua` — Lua script to validate capture logic, nil-safety, JSON structure
- [ ] `bin/test-phase2.sh` — Shell wrapper to run Lua tests via `wezterm cli spawn`
- [ ] Manual test checklist document (or embedded in PLAN.md) — REQ-09 feature verification

## Sources

### Primary (HIGH confidence)
- WezTerm official documentation — https://wezfurlong.org/wezterm/config/lua/wezterm.mux/ (verified `panes_with_info()`, `get_current_working_dir()` APIs)
- WezTerm changelog — https://wezfurlong.org/wezterm/changelog.html (verified `json_encode()` available since 20220807)
- Existing wezterm.lua — /Users/t026chirv/.config/wezterm/wezterm.lua (verified `io.open()`, `update-status` event, `wezterm.GLOBAL` patterns)
- Phase 1 research — .planning/phases/01-daemon-infrastructure/01-RESEARCH.md (verified mux domain patterns, module structure)

### Secondary (MEDIUM confidence)
- Stack research — .planning/research/STACK.md (verified WezTerm API versions and capabilities)
- Pitfalls research — .planning/research/PITFALLS.md (verified nil-handling, URI parsing, debouncing requirements)
- Architecture research — .planning/research/ARCHITECTURE.md (verified JSON schema patterns, data flow)

### Tertiary (LOW confidence)
- None — all findings verified with official sources or existing code

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - WezTerm APIs documented and verified in running config (version 20240203)
- Architecture: HIGH - Patterns tested in existing config (`io.open()` for theme-mode, `wezterm.GLOBAL` for tab lock)
- Pitfalls: HIGH - Nil-handling and URI parsing issues documented in project roadmap and existing research
- Validation: MEDIUM - No established WezTerm Lua test framework, relying on manual tests + shell scripts

**Research date:** 2026-03-14
**Valid until:** 2026-04-14 (30 days — WezTerm APIs are stable, patterns unlikely to change)
