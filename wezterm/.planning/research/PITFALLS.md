# Domain Pitfalls: WezTerm Session Management

**Domain:** Terminal session management with WezTerm native multiplexer
**Researched:** 2026-03-14

## Critical Pitfalls

These mistakes cause rewrites, data loss, or major functionality failures.

### Pitfall 1: `get_foreground_process_name()` Returns `nil` for Mux/SSH Panes
**What goes wrong:** When calling `pane:get_foreground_process_name()` on multiplexer or SSH domain panes, the API returns `nil` instead of the process name. This breaks process detection logic and causes crashes when attempting to call string methods (like `:find()`) on the nil value.

**Why it happens:** The foreground process detection only works for local panes in stable WezTerm. Remote and multiplexer domains don't expose process information through the Lua API.

**Consequences:**
- Session restoration crashes with "attempt to index a nil value" error
- Cannot distinguish between shell processes (safe to close) and running applications (preserve)
- Process restoration becomes impossible for mux-based sessions
- User loses context about what was running in each pane

**Prevention:**
- Always nil-check the result of `get_foreground_process_name()` before calling string methods
- Implement fallback behavior: assume shell if nil, or skip process restoration entirely for mux panes
- Consider storing process information in session metadata (pid, command line) as backup
- Document that process restoration only works for local domains

**Detection:**
- Error logs: "attempt to index a nil value (local 'foreground_process')"
- Process restoration silently fails for mux/SSH panes
- Session save succeeds but restore crashes

**Phase Impact:** Phase 2 (Layout Persistence) - Must handle nil process names before attempting any process restoration.

**Sources:**
- https://github.com/danielcopper/wezterm-session-manager/issues/16

---

### Pitfall 2: Complex Pane Layout Geometry Cannot Be Reliably Reconstructed
**What goes wrong:** WezTerm's `panes_with_info()` API returns pane coordinates (left, top, width, height) but provides no explicit tree structure of splits. Attempting to recreate complex layouts (3+ panes with mixed horizontal/vertical splits) by comparing coordinates produces incorrect layouts.

**Why it happens:** The naive approach compares `pane_data.left == previous_pane.left` to determine split direction (Bottom vs Right), but this heuristic fails for:
- L-shaped layouts (3-pane: top-left, bottom-left, right spanning full height)
- Grid layouts (4+ panes in 2x2 or 3x2 arrangements)
- Nested splits (pane A splits horizontally, then left child splits vertically)
- Uneven split percentages

The API doesn't expose the split tree — only final rendered positions.

**Consequences:**
- Restored layouts look scrambled or wrong
- Panes appear in different positions than saved
- Split percentages reset to default 50/50
- User loses carefully tuned workspace layouts

**Prevention:**
- Accept that only simple layouts (all horizontal OR all vertical splits) can be reliably restored
- Document layout restoration limitations upfront in README
- Consider building split tree explicitly during save by tracking split operations via custom events (high complexity)
- Store split direction and percentage hints in session JSON (requires user discipline or instrumentation)
- For MVP: Restore only CWD and processes to correct tabs/panes, warn users layout geometry is approximate

**Detection:**
- User reports: "My layout looks different after restore"
- Panes in wrong positions relative to each other
- All splits default to 50/50 even if original was 70/30

**Phase Impact:** Phase 2 (Layout Persistence) - Accept limitations or invest heavily in split tree tracking.

**Sources:**
- https://github.com/danielcopper/wezterm-session-manager (README limitations section)
- https://github.com/wezterm/wezterm/issues/3237

---

### Pitfall 3: `wezterm cli` Commands Execute Out of Order in Batch Scripts
**What goes wrong:** When running multiple `wezterm cli` commands sequentially in a shell script (e.g., `activate-tab`, then `split-pane`), the commands execute asynchronously without waiting for each other. This causes operations to target the wrong tab/pane state.

**Why it happens:** The `wezterm cli` communicates with the mux server over a socket using async RPC. Each command returns immediately after sending the message, not after the server completes the operation. The server processes commands in received order, but the client script continues without waiting.

**Consequences:**
- `split-pane` targets tab 0 instead of newly activated tab 1
- `spawn` creates panes in unexpected tabs
- Complex session initialization scripts produce scrambled layouts
- Restoration logic becomes unreliable for multi-tab/multi-pane setups

**Prevention:**
- Insert explicit `sleep 0.1` between CLI commands to allow server to process (fragile, timing-dependent)
- Use Lua `mux` API instead of shell scripts for session initialization (synchronous API)
- Perform session restoration entirely from Lua event handlers (`mux-startup`, `restore_session`)
- If CLI is required, use `wezterm cli list` as synchronization barrier to confirm state before next command
- For MVP: Do all session management in Lua, avoid CLI for batch operations

**Detection:**
- Panes/tabs appear in wrong locations during scripted restore
- Works when commands run manually, fails in batch script
- Adding delays "fixes" the issue (symptom of race condition)

**Phase Impact:** Phase 1 (CLI Wrapper) - Avoid CLI for complex operations. Phase 4 (Session Restore) - Use Lua API exclusively.

**Sources:**
- https://github.com/wezterm/wezterm/issues/7368

---

### Pitfall 4: `mux.spawn_window` with `domain` Parameter Creates Duplicate Tabs
**What goes wrong:** Calling `mux.spawn_window({ domain = { DomainName = "my_domain" } })` creates 12-16 empty, unusable tabs in addition to the expected single tab. Only the first tab contains the spawned process; remaining tabs are named after the process but cannot be interacted with.

**Why it happens:** Bug in WezTerm's mux domain spawning logic when domain is explicitly specified. The multiplexer incorrectly iterates spawn logic or duplicates tab creation. Does not occur when `domain` parameter is omitted (uses current domain).

**Consequences:**
- Session initialization creates unusable zombie tabs
- User must manually close 10+ tabs on every session start
- Confusing UX — which tab is real?
- Breaks automated workspace setup

**Prevention:**
- Avoid specifying `domain` parameter in `mux.spawn_window` if possible (spawn in current domain)
- If domain-specific spawning is required, switch to domain first with `mux.set_active_workspace()` then spawn without domain param
- Track upstream bug status — may be fixed in recent nightlies
- Test spawning behavior thoroughly before releasing daemon-based session manager

**Detection:**
- Multiple tabs appear when only one expected
- Tabs have identical names but only first is functional
- Issue occurs consistently on every spawn with domain parameter

**Phase Impact:** Phase 1 (Daemon Setup) and Phase 3 (Session Operations) - Must validate spawning behavior with mux server.

**Sources:**
- https://github.com/wezterm/wezterm/issues/4408

---

## Moderate Pitfalls

These cause degraded UX or require workarounds but don't break core functionality.

### Pitfall 5: Rapid Tab Switching in Mux Server Triggers "Tab Switching Frenzy"
**What goes wrong:** When quickly switching tabs using keyboard shortcuts (Cmd+Shift+[ / ]) while connected to wezterm-mux-server over SSH/VPN, the terminal enters an uncontrolled tab-switching loop that continues for several seconds.

**Why it happens:** Network latency causes tab switch commands to queue up. The server processes them sequentially, but each switch triggers UI updates that the client interprets as new switch events, creating a feedback loop.

**Consequences:**
- Tab switching becomes unusable for ~3-5 seconds
- User loses control of terminal during episode
- Disorienting UX for remote mux users
- May cause accidental command execution in wrong tab

**Prevention:**
- Rate-limit tab switch keybindings in config (debounce ~200ms)
- Use workspace switcher instead of rapid tab navigation for mux sessions
- Document that rapid tab switching is problematic over network
- Consider switching focus away and back to break the loop (Cmd-Tab workaround)

**Detection:**
- Terminal rapidly cycles through tabs without input
- Occurs more frequently with higher network latency
- Stops after a few seconds or when switching window focus

**Phase Impact:** Phase 5 (Fuzzy Picker) - Design picker to avoid rapid succession of switch commands. Consider workspace-level switching instead of tab-level.

**Sources:**
- https://github.com/wezterm/wezterm/issues/3994

---

### Pitfall 6: `set-working-directory` CLI Command Ignored at Startup
**What goes wrong:** Running `wezterm set-working-directory /tmp` then `wezterm start` spawns a shell in `~` instead of `/tmp`. The working directory hint is lost.

**Why it happens:** `set-working-directory` communicates with a running mux instance, but `wezterm start` may spawn a new mux or window that doesn't inherit the stored CWD preference. The CWD hint is stored in the client, not the mux server state.

**Consequences:**
- Session restore cannot set CWD before spawning panes via CLI
- Workarounds require complex shell scripting
- Forces use of Lua API for CWD control

**Prevention:**
- Use `wezterm cli spawn --cwd /path` instead of `set-working-directory` + `start`
- Perform all CWD-sensitive spawning from Lua API using `mux.spawn_window({ cwd = path })`
- Don't rely on `set-working-directory` for session automation

**Detection:**
- New panes/tabs ignore intended CWD
- Spawned in `~` regardless of `set-working-directory` call
- Works when mux is already running, fails on first start

**Phase Impact:** Phase 1 (CLI Wrapper) - Don't use `set-working-directory`. Phase 4 (Session Restore) - Use Lua API for CWD.

**Sources:**
- https://github.com/wezterm/wezterm/issues/4121

---

### Pitfall 7: Windows Path Extraction from `file:///` URIs Differs from Unix
**What goes wrong:** `pane:get_current_working_dir()` returns URIs like `file:///C:/path` (Windows) vs `file://{hostname}/home/user/path` (Linux) vs `file:///Users/user/path` (macOS). Naive string parsing breaks cross-platform session files.

**Why it happens:** Different OS conventions for file URIs. Windows uses drive letters, Linux includes hostname, macOS is simpler. The WezTerm API returns raw URIs without normalization.

**Consequences:**
- Session files saved on one OS cannot be restored on another
- Path extraction logic must have platform-specific branches
- Testing becomes platform-dependent

**Prevention:**
- Implement platform-aware URI parsing using `wezterm.target_triple` to detect OS
- Extract path with regex patterns per platform:
  - Windows: `gsub("file:///", "")`
  - Linux: `gsub("^.*(/home/)", "/home/")`
  - macOS: `gsub("^.*(/Users/)", "/Users/")`
- Consider normalizing paths in session JSON to Unix-style (convert on save/restore)
- Test session save/restore on all three platforms before release

**Detection:**
- Panes spawn in wrong directory after restore
- Path looks malformed (`file://...` prefix remains)
- Works on dev machine, breaks on user's different OS

**Phase Impact:** Phase 2 (Layout Persistence) - Must implement platform-aware path extraction.

**Sources:**
- https://github.com/danielcopper/wezterm-session-manager (session-manager.lua lines 85-95)

---

### Pitfall 8: Process Restoration Requires Hardcoded Command Detection
**What goes wrong:** To restore processes (e.g., `nvim`, `npm dev`), the code must parse `tty` strings and detect specific commands. This requires hardcoding known process patterns, which is fragile and incomplete.

**Why it happens:** No generic way to serialize arbitrary process state. Can only re-run the command, but:
- Many processes (servers, REPLs, editors) have state (open files, history, buffers)
- Command-line arguments may not be preserved
- Some processes should not be auto-restarted (builds, one-time scripts)

**Consequences:**
- Only specific processes (nvim, shells) restore correctly
- Long-running processes (npm dev) restart but lose state
- User may not want certain processes auto-restarted
- Hardcoded process list becomes maintenance burden

**Prevention:**
- For MVP: Only restore shells and `nvim` (most common)
- Send process command as text, let user manually restart others
- Provide session file editing capability so users can tweak `tty` strings
- Consider allowlist/denylist in config for auto-restart processes
- Document that full process state restoration is impossible — only command re-execution

**Detection:**
- Some processes restore, others don't
- Processes restart but lose state (editor forgets open files)
- User confusion about which processes will auto-restart

**Phase Impact:** Phase 4 (Command Restoration) - Accept limitations, focus on shells + nvim.

**Sources:**
- https://github.com/danielcopper/wezterm-session-manager (session-manager.lua lines 160-170)
- https://github.com/abidibo/wezterm-sessions (README notes about process restoration)

---

## Minor Pitfalls

These are nuisances or edge cases that degrade polish.

### Pitfall 9: Restoration Requires Single Tab + Single Pane to Prevent "Data Loss"
**What goes wrong:** Most session managers check that the current window has exactly one tab with one pane before restoring. If multiple tabs/panes exist, restoration aborts to avoid "accidental data loss."

**Why it happens:** Restoration overwrites the current window's tab/pane structure. If user has unsaved work in other tabs, restoration would close them.

**Consequences:**
- User must manually close extra tabs before restoring
- Confusing error message: "Restoration can only be performed in a window with a single tab and a single pane"
- Workflow friction — can't quickly restore to existing window

**Prevention:**
- Offer two restore modes:
  1. **Replace**: Require single tab/pane (safe mode)
  2. **Append**: Restore tabs alongside existing tabs (advanced mode)
- Prompt user: "Restore will close existing tabs. Continue? [y/N]"
- Spawn new window for restoration, leave current window untouched
- Default to safe mode for MVP

**Detection:**
- Restore command does nothing when multiple tabs exist
- Error message: "single tab and single pane required"
- User must manually clean workspace before restoring

**Phase Impact:** Phase 4 (Session Restore) - Implement single-tab check or new-window spawning.

**Sources:**
- https://github.com/danielcopper/wezterm-session-manager (session-manager.lua lines 96-100)

---

### Pitfall 10: Session Files Stored in `.config/wezterm` Pollute Config Directory
**What goes wrong:** Storing session JSON files as `~/.config/wezterm/wezterm_state_<workspace>.json` mixes session data with configuration files. Over time, dozens of session files accumulate alongside `wezterm.lua`.

**Why it happens:** No dedicated session storage location. Easy to implement but poor separation of concerns.

**Consequences:**
- Config directory becomes cluttered
- Harder to version-control config (session state is ephemeral, config is static)
- Users must manually exclude session files from git
- Backup/sync tools capture session state unintentionally

**Prevention:**
- Store sessions in dedicated subdirectory: `~/.config/wezterm/sessions/`
- Or use XDG standard: `~/.local/share/wezterm/sessions/`
- Make session directory configurable in plugin options
- Add `.gitignore` entry for session files by default
- Document session storage location in README

**Detection:**
- Many `wezterm_state_*.json` files in config directory
- Session files appear in git status
- Difficulty finding `wezterm.lua` among session files

**Phase Impact:** Phase 2 (Layout Persistence) - Choose clean storage location from start.

**Sources:**
- https://github.com/danielcopper/wezterm-session-manager (session-manager.lua line 228)

---

### Pitfall 11: Initial Pane Must Be Closed Before Restoration (Fragile Shell Detection)
**What goes wrong:** Restoration logic sends `exit\r` to the initial pane to close it before spawning session tabs. It checks if the foreground process is a shell (contains "sh", "cmd.exe", "powershell", etc.) before sending exit. If detection fails, initial pane remains and restoration creates duplicate content.

**Why it happens:** Restoration needs a "clean slate" window. Rather than spawning a new window, it attempts to reuse the initial pane's window by closing the initial pane first.

**Consequences:**
- If shell detection heuristic misses a shell (e.g., `fish`, `nu`, `dash`), initial pane isn't closed
- User sees extra empty tab alongside restored session
- If detection incorrectly identifies a running program as a shell, sends `exit` to that program (data loss)
- Shell detection list must be maintained as new shells emerge

**Prevention:**
- Expand shell detection list: `sh`, `bash`, `zsh`, `fish`, `nu`, `dash`, `tcsh`, `ksh`, `cmd.exe`, `powershell`, `pwsh`
- Or: Always spawn session in a new window, avoid closing initial pane
- Or: Prompt user: "Close initial pane? [y/N]"
- Or: Check `SHELL` environment variable instead of process name heuristic

**Detection:**
- Extra empty tab appears after restore
- Foreground program unexpectedly receives `exit` command
- Log message: "Active program detected. Skipping exit command"

**Phase Impact:** Phase 4 (Session Restore) - Improve shell detection or spawn new window.

**Sources:**
- https://github.com/danielcopper/wezterm-session-manager (session-manager.lua lines 102-108)

---

## Phase-Specific Warnings

These pitfalls are particularly relevant to specific phases of the project roadmap.

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| **Phase 1: Daemon Setup** | Mux server crashes or becomes unresponsive over time | Monitor mux memory usage; implement health check; auto-restart on failure |
| **Phase 1: Daemon Setup** | launchd plist misconfiguration prevents daemon start | Test launchd setup on fresh macOS install; validate plist with `launchctl bootstrap` |
| **Phase 2: Layout Persistence** | Complex layouts restore incorrectly | Document layout limitations; focus on simple horizontal/vertical splits for MVP |
| **Phase 2: Layout Persistence** | `get_current_working_dir()` returns nil for some panes | Nil-check all CWD calls; fall back to `~` if nil |
| **Phase 3: Session Operations** | `spawn_window` with domain creates duplicate tabs | Avoid domain parameter or switch domains before spawning |
| **Phase 4: Command Restoration** | Hardcoded process list doesn't cover user's tools | Make process list configurable; allow session JSON editing |
| **Phase 4: Session Restore** | `get_foreground_process_name()` returns nil for mux panes | Nil-check before calling string methods; skip process restore for mux |
| **Phase 5: Fuzzy Picker** | Rapid selection causes tab switching frenzy | Debounce selection; use workspace switching instead of tab switching |
| **Phase 6: CLI Wrapper** | CLI commands execute out of order in batch | Use Lua API for session operations; avoid CLI for automation |

---

## General Warnings

### Mux Server Memory Leaks
**Issue:** Long-running mux servers may accumulate memory from unclosed panes, image buffers, or PDU allocation bugs.

**Warning Signs:**
- Mux process memory grows over days/weeks
- WezTerm becomes slow or unresponsive
- macOS Activity Monitor shows wezterm-mux-server using GBs of RAM

**Mitigation:**
- Monitor mux memory via launchd or system metrics
- Implement periodic mux restart (e.g., weekly cron)
- Encourage users to close unused sessions
- Track upstream issues: https://github.com/wezterm/wezterm/issues/7527 (OOM crashes), https://github.com/wezterm/wezterm/issues/5128 (image memory leaks)

---

### Platform Differences (macOS vs Linux)
**Issue:** Code tested on macOS may break on Linux due to path differences, systemd vs launchd, or process name variations.

**Warning Signs:**
- Session restore works on dev machine, fails on user's Linux box
- Path extraction breaks for Linux URI format
- Daemon doesn't start with systemd

**Mitigation:**
- Test on Linux VM before release
- Use `wezterm.target_triple` to detect platform
- Provide both launchd plist (macOS) and systemd unit (Linux)
- Document platform-specific installation steps

---

### Session File Format Stability
**Issue:** Changing JSON schema breaks backward compatibility. Users lose access to old sessions.

**Warning Signs:**
- Updated session manager can't load old session files
- User complaints: "All my sessions disappeared after update"

**Mitigation:**
- Version session file format: `{ "version": 1, "workspace": ... }`
- Implement schema migration on load
- Test loading old session files after schema changes
- Document breaking changes in release notes

---

## Validation Checklist

Before releasing session management functionality, validate:

- [ ] `get_foreground_process_name()` nil-checked everywhere
- [ ] Path extraction tested on macOS, Linux, Windows
- [ ] Session files stored in clean directory (not cluttering config root)
- [ ] Restoration works from single-tab window (or spawns new window)
- [ ] Complex layouts documented as unsupported
- [ ] CLI batch scripts avoided in favor of Lua API
- [ ] Shell detection covers common shells (bash, zsh, fish, nu, pwsh)
- [ ] Mux daemon starts successfully on fresh macOS install
- [ ] Session JSON schema versioned for future migrations
- [ ] `mux.spawn_window` tested without domain parameter

---

## Confidence Assessment

**Overall confidence:** HIGH — Research draws from real-world WezTerm session manager implementations, upstream bug reports, and API limitations documented in issues.

| Area | Confidence | Notes |
|------|------------|-------|
| API limitations (foreground process, CWD) | HIGH | Confirmed by multiple session manager projects and upstream issues |
| Complex layout restoration | HIGH | Explicitly documented as limitation in existing projects |
| CLI command ordering | HIGH | Confirmed by upstream bug report with detailed reproduction |
| Mux domain spawning | HIGH | Confirmed by upstream bug report with code sample |
| Platform differences | MEDIUM | Derived from code inspection; not all platforms tested |
| Memory leaks | MEDIUM | Upstream issues exist but root causes vary |

---

## Sources

### Primary Sources (High Confidence)
- **danielcopper/wezterm-session-manager**: https://github.com/danielcopper/wezterm-session-manager
  - Issue #16: Multiplexer panes `get_foreground_process_name()` returns nil
  - Issue #21: Windows path extraction differences
  - README: Complex layout limitations documented
- **abidibo/wezterm-sessions**: https://github.com/abidibo/wezterm-sessions
  - README: Process restoration limitations for Linux/macOS only
- **wez/wezterm issues**:
  - #3237: Feature request for layout saving (indicates no native support)
  - #3994: Tab switching frenzy in mux server
  - #4121: `set-working-directory` ignored at startup
  - #4408: `mux.spawn_window` creates duplicate tabs with domain parameter
  - #7368: CLI commands execute out of order in batch scripts

### Supporting Sources (Medium Confidence)
- **Other session managers**: mikosaurus/wezterm-sessionizer, scrythe/wezterm-session-manager, bowojori7/wezterm-persist
- **Upstream issues**: #7527 (OOM crashes), #5128 (image memory leaks), #3385 (mux-server version compatibility)
