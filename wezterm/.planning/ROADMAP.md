# Roadmap: WezTerm Session Manager

## Overview

This roadmap delivers a native session management system for WezTerm in 7 phases, following a foundation-first approach: daemon infrastructure and serialization before user-facing features. The ordering is driven by dependency analysis -- session persistence requires a running daemon, layout restore requires a working serializer, and pickers require a working session manager. Each phase delivers a coherent, independently verifiable capability.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Daemon Infrastructure** - Persistent mux server via launchd with unix domain, project scaffolding
- [ ] **Phase 2: Layout Serialization** - Capture workspace state (tabs, panes, CWDs, processes) to JSON
- [ ] **Phase 3: Session Manager Core** - Lua module for session CRUD (create, list, save, delete)
- [x] **Phase 4: Shell CLI** - `wez-session` command with subcommands for session management (completed 2026-03-14)
- [x] **Phase 5: Layout Restoration** - Rebuild sessions from JSON (tabs, panes, CWDs, commands) (completed 2026-03-14)
- [x] **Phase 6: Fuzzy Picker** - Keybinding-triggered session selector using InputSelector (completed 2026-03-14)
- [ ] **Phase 7: Picker Delete Mode** - Delete sessions from picker via sentinel-based mode switching

## Phase Details

### Phase 1: Daemon Infrastructure
**Goal**: WezTerm panes survive closing all GUI windows and persist across login sessions
**Depends on**: Nothing (first phase)
**Requirements**: REQ-01, REQ-08, REQ-10
**Success Criteria** (what must be TRUE):
  1. User can close all WezTerm windows, reopen WezTerm, and find previous panes still running
  2. Mux server starts automatically on macOS login without user intervention
  3. Project file structure exists (`lua/session/`, `sessions/`, `bin/`) and loads without breaking existing wezterm.lua features (theme toggle, smart-splits, tab lock, hints bar)
  4. `wezterm connect local-mux` attaches to the running daemon and shows existing panes
**Plans**: 2 plans

**Research flags**: SKIP -- launchd is a well-documented macOS pattern
**Risks**:
  - Pitfall #4: `mux.spawn_window` with domain parameter creates duplicate tabs -- test daemon spawning behavior early
  - Pitfall: launchd plist misconfiguration prevents daemon start -- validate plist with `launchctl bootstrap`
  - Pitfall: Mux server crashes or becomes unresponsive over time -- implement KeepAlive in plist

Plans:
- [x] 01-01-PLAN.md -- Daemon infrastructure: project scaffolding, launchd plist, CLI wrapper, Lua session modules
- [x] 01-02-PLAN.md -- Config integration: wire session modules into wezterm.lua, mux status indicator, human verification

### Phase 2: Layout Serialization
**Goal**: Current workspace state can be captured to a human-readable, git-versionable JSON file
**Depends on**: Phase 1
**Requirements**: REQ-09
**Success Criteria** (what must be TRUE):
  1. User can trigger a save and find a JSON file in `~/.config/wezterm/sessions/` that accurately describes their current tabs, pane splits, and working directories
  2. JSON file is human-readable and produces clean diffs when version-controlled with git
  3. Running process names (e.g., `nvim`, `npm`) are captured in the JSON when detectable
**Plans**: 3 plans

**Research flags**: LIGHT -- need to validate nil-handling patterns for `get_foreground_process_name()` and `get_current_working_dir()`
**Risks**:
  - Pitfall #1: `get_foreground_process_name()` returns nil for mux panes -- must nil-check before calling string methods
  - Pitfall #2: Complex pane layouts cannot be reliably reconstructed from coordinates -- accept simple layouts only for MVP
  - Pitfall #7: Path extraction from `file:///` URIs differs across platforms -- implement platform-aware parsing via `wezterm.target_triple`
  - Pitfall #10: Session files in config root pollute directory -- use dedicated `sessions/` subdirectory

Plans:
- [x] 02-00-PLAN.md -- Wave 0: test infrastructure (bin/test-phase2.sh)
- [ ] 02-01-PLAN.md -- State module: layout introspection, nil-safe extraction, JSON serialization, atomic file write
- [ ] 02-02-PLAN.md -- Auto-save integration: debounced save in update-status handler, human verification of end-to-end flow

### Phase 3: Session Manager Core
**Goal**: Lua API exists for all session lifecycle operations, usable by both CLI and picker UIs
**Depends on**: Phase 2
**Requirements**: REQ-02
**Success Criteria** (what must be TRUE):
  1. User can create a new named session (workspace) that appears as a distinct WezTerm workspace
  2. User can list all saved sessions and see their names and last-saved timestamps
  3. User can delete a session, removing both the workspace and its JSON file
  4. Switching to a session activates the corresponding WezTerm workspace
**Plans**: 1 plan

**Research flags**: SKIP -- straightforward Lua module design
**Risks**:
  - Pitfall #4: `mux.spawn_window` with domain parameter creates duplicate tabs -- spawn without domain parameter, switch workspace first

Plans:
- [ ] 03-01-PLAN.md -- Session manager module: CRUD operations (create/list/switch/delete), init.lua wiring, human verification

### Phase 4: Shell CLI
**Goal**: Users can manage sessions from any terminal via the `wez-session` command
**Depends on**: Phase 3
**Requirements**: REQ-07
**Success Criteria** (what must be TRUE):
  1. User can run `wez-session create <name>` to create a named session
  2. User can run `wez-session list` to see all sessions with their status
  3. User can run `wez-session save [name]` to persist current workspace state
  4. User can run `wez-session delete <name>` to remove a session
**Plans**: 1 plan

**Research flags**: SKIP -- standard shell scripting
**Risks**:
  - Pitfall #3: CLI commands execute out of order in batch scripts -- use Lua API for complex operations, CLI only for user-facing commands
  - Pitfall #6: `set-working-directory` ignored at startup -- use `wezterm cli spawn --cwd` instead

Plans:
- [ ] 04-01-PLAN.md -- Session CLI: add create/list/save/delete subcommands to wez-session, test suite, human verification

### Phase 5: Layout Restoration
**Goal**: Users can fully restore a saved session -- tabs, pane splits, working directories, and running commands reappear
**Depends on**: Phase 4
**Requirements**: REQ-03, REQ-04
**Success Criteria** (what must be TRUE):
  1. User can run `wez-session attach <name>` and see their saved tabs and pane splits recreated
  2. Each restored pane opens in its previously saved working directory
  3. Commands like `nvim` and `npm run dev` are re-launched in the correct panes
  4. Restoration works into a new workspace without disrupting existing sessions
**Plans**: 2 plans

**Research flags**: DEEP -- complex interactions between APIs, async spawn timing, nil handling, platform path differences all converge here
**Risks**:
  - Pitfall #1: `get_foreground_process_name()` returns nil for mux panes -- skip process restoration for mux panes
  - Pitfall #2: Complex layouts restore incorrectly -- accept simple horizontal/vertical splits only
  - Pitfall #3: CLI commands execute out of order -- use Lua API exclusively for session restoration
  - Pitfall #5: Rapid tab switching triggers feedback loop -- use workspace switching, not tab switching
  - Pitfall #8: Process restoration requires hardcoded command detection -- start with shells + nvim + claude, make configurable
  - Pitfall #9: Restoration requires single tab/pane -- spawn new window for restored sessions
  - Pitfall #11: Initial pane closure relies on fragile shell detection -- spawn new window instead of reusing initial pane

Plans:
- [ ] 05-01-PLAN.md -- Restore module: test infrastructure, Lua restore API in manager.lua (attach/restore/split/configure)
- [ ] 05-02-PLAN.md -- CLI attach: wez-session attach subcommand with JSON-based restoration, human verification

### Phase 6: Fuzzy Picker
**Goal**: Users can switch sessions instantly via a keyboard-triggered fuzzy search overlay
**Depends on**: Phase 5
**Requirements**: REQ-05
**Success Criteria** (what must be TRUE):
  1. User presses CMD+CTRL+S and sees a searchable list of all sessions
  2. Selecting a session switches to it immediately if already active, or restores it from JSON if not
  3. Current session is visually indicated in the picker list
**Plans**: 1 plan

**Research flags**: LIGHT -- `InputSelector` is documented, pattern exists in WezTerm examples
**Risks**:
  - Pitfall #5: Rapid selection causes tab switching frenzy -- use workspace switching, debounce selection

Plans:
- [ ] 06-01-PLAN.md -- Picker module: InputSelector-based fuzzy picker, CMD+CTRL+S keybinding, create-if-not-found, human verification

### Phase 7: Picker Delete Mode
**Goal**: Users can delete sessions directly from the fuzzy picker without dropping to CLI
**Depends on**: Phase 6
**Requirements**: REQ-06
**Success Criteria** (what must be TRUE):
  1. User selects "Delete mode" sentinel in the session picker to enter delete mode with visual indicator
  2. Selecting a session in delete mode shows a confirmation before deleting
  3. After deletion, picker refreshes showing remaining sessions (or returns to switch mode)
**Plans**: 1 plan

**Research flags**: LIGHT -- extends existing picker.lua, manager.delete_session() already exists
**Risks**:
  - Pitfall: Accidental deletion -- confirmation step is mandatory
  - InputSelector does not support Tab key capture -- use sentinel approach for mode switching

Plans:
- [ ] 07-01-PLAN.md -- Delete mode: sentinel-based mode switching in picker.lua, PromptInputLine confirmation, human verification

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Daemon Infrastructure | 2/2 | Complete | 2026-03-14 |
| 2. Layout Serialization | 0/3 | Not started | - |
| 3. Session Manager Core | 0/1 | Not started | - |
| 4. Shell CLI | 1/1 | Complete   | 2026-03-14 |
| 5. Layout Restoration | 2/2 | Complete   | 2026-03-14 |
| 6. Fuzzy Picker | 1/1 | Complete   | 2026-03-14 |
| 7. Picker Delete Mode | 0/1 | Not started | - |

## Coverage

| Requirement | Phase | Verified |
|-------------|-------|----------|
| REQ-01: Mux daemon via launchd | Phase 1 | Y |
| REQ-08: Shell + Lua architecture | Phase 1 | Y |
| REQ-10: Integration with existing config | Phase 1 | Y |
| REQ-09: JSON session storage | Phase 2 | Y |
| REQ-02: Named session CRUD | Phase 3 | Y |
| REQ-07: CLI wrapper (wez-session) | Phase 4 | Y |
| REQ-03: Layout save/restore | Phase 5 | Y |
| REQ-04: Command capture/restore | Phase 5 | Y |
| REQ-05: Fuzzy session picker | Phase 6 | Y |
| REQ-06: Picker delete mode | Phase 7 | Y |

**Coverage: 10/10 requirements mapped. No orphans.**

---
*Created: 2026-03-14*
