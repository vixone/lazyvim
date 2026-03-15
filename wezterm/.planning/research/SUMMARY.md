# Project Research Summary

**Project:** WezTerm Native Session Management
**Domain:** Terminal session management
**Researched:** 2026-03-14
**Confidence:** MEDIUM-HIGH

## Executive Summary

This project aims to build a tmux-like session manager natively within WezTerm, leveraging WezTerm's built-in multiplexer to provide persistent terminal sessions without external dependencies. The research reveals that WezTerm provides all necessary primitives (unix domains, workspaces, mux API, CLI tools) to implement session persistence, but the ecosystem is immature with several gotchas around process detection, layout reconstruction, and CLI command ordering.

The recommended approach is daemon-first: configure a persistent mux server via launchd (macOS), map WezTerm workspaces 1:1 to named sessions, and serialize layouts to git-versionable JSON files. This gives tmux-level persistence with zero external dependencies. The differentiators are git-versioned session definitions and command restoration (re-launching `nvim`, `npm dev` on restore).

Key risks center on API limitations: `get_foreground_process_name()` returns nil for mux panes (breaks process detection), complex layout geometries cannot be reliably reconstructed from `panes_with_info()` output, and CLI commands execute asynchronously (causing race conditions in batch scripts). Mitigation requires defensive nil-checking, accepting simple-layout-only restoration, and performing all session management via Lua API instead of shell scripting.

## Key Findings

### Recommended Stack

WezTerm native multiplexing provides the foundation for session management without external dependencies. The core insight is that unix domains enable persistence (panes survive GUI closure), workspaces provide logical session boundaries, and the Lua API gives full introspection and control. This eliminates the complexity of tmux/zellij integration while enabling tighter integration with WezTerm features.

**Core technologies:**
- **WezTerm Built-in Mux (20240203+)**: Multiplexer daemon for persistent sessions — native, zero dependencies, designed for this exact use case
- **WezTerm Lua API**: Session introspection and management via `wezterm.mux`, `pane:get_current_working_dir()`, `tab:panes_with_info()` — first-class integration
- **wezterm cli**: Programmatic control with JSON output (`wezterm cli list --format json`) — designed for automation
- **JSON (native Lua)**: Session persistence format — human-readable, diffable, git-versioned with built-in parsing
- **launchd (macOS)**: Daemon lifecycle management — ensures mux server survives logout, auto-restart on failure
- **Shell Script (bash/zsh)**: CLI wrapper for user interface — portable, no compilation needed

**Version requirements:** WezTerm 20220807+ for `panes_with_info()` and JSON support. User version 20240203 is fully compatible.

### Expected Features

Research into tmux/zellij usage patterns and existing WezTerm session manager plugins reveals clear feature tiers.

**Must have (table stakes):**
- Named session creation/listing/attach — core concept users expect from tmux
- Session persistence across disconnects — the killer feature (requires daemon)
- Layout save/restore (tabs + panes + directories) — basic workflow preservation
- Multiple tabs/windows per session — expected organization primitive
- Pane splitting (vertical/horizontal) — standard multiplexer feature
- Session kill/delete — lifecycle management
- Fuzzy session picker — better UX than `tmux ls`

**Should have (competitive advantage):**
- Git-versioned session definitions — nobody does this well (store JSON in repo)
- Command restoration — killer feature (re-launch `nvim`, `npm dev` on restore)
- Session templates — pre-defined layouts for common workflows
- Layout auto-save on changes — sessions always reflect current state
- Zero external dependencies — works out of WezTerm install

**Defer (v2+):**
- Remote session support (SSH domains) — complex, defer until local proven
- Multi-machine sync — defer until git-versioning workflow validated
- Session snapshots/versioning — defer until users request time-travel debugging

**Anti-features (do not implement):**
- Auto-restore all sessions on launch — overwhelming, prefer picker
- Automatic command history replay — dangerous (side effects)
- Remote session sync — complex state synchronization
- GUI session manager app — violates terminal-first philosophy

### Architecture Approach

The architecture follows a daemon + CLI pattern common in terminal multiplexers: a persistent background process (mux server) holds live state, user-facing tools interact via IPC, and ephemeral state is serialized to JSON for restoration. The key insight is using WezTerm workspaces as session boundaries (1:1 mapping) rather than building custom multiplexing.

**Major components:**
1. **WezTerm Mux Server** — persistent daemon holding pane state in memory, managed by launchd
2. **Session Manager (Lua)** — core logic for session CRUD, orchestrates serialization and workspace control
3. **Layout Serializer (Lua)** — converts live pane/tab state to/from JSON via `wezterm.mux` APIs
4. **Shell CLI (`wez-session`)** — user-facing command interface (create, list, attach, save, kill)
5. **Fuzzy Picker (Lua)** — interactive session selection UI using `InputSelector`
6. **Session Storage (JSON)** — files in `~/.config/wezterm/sessions/`, git-versioned for portability

**File structure:**
```
~/.config/wezterm/
├── wezterm.lua              # Main config
├── bin/wez-session          # CLI wrapper
├── lua/session/             # Lua modules
│   ├── manager.lua          # Session CRUD
│   ├── serializer.lua       # Layout to/from JSON
│   ├── picker.lua           # Fuzzy picker UI
│   └── startup.lua          # On-launch picker
├── sessions/*.json          # Session files (git-versioned)
└── launchd/com.wezterm.mux.plist
```

**Key patterns:**
- **Daemon + CLI Architecture**: Persistent mux server ensures sessions survive window closure
- **Workspace as Session**: Each WezTerm workspace = one named session (native feature)
- **JSON Snapshot + Replay**: Serialize layout to human-readable JSON, restore by replaying commands

### Critical Pitfalls

Research into existing WezTerm session managers and upstream issues reveals several API limitations and race conditions.

1. **`get_foreground_process_name()` returns nil for mux/SSH panes** — breaks process detection, requires nil-checking everywhere before calling string methods. Workaround: assume shell if nil, skip process restoration for mux panes.

2. **Complex pane layouts cannot be reliably reconstructed** — `panes_with_info()` returns coordinates but no split tree. L-shaped, grid, and nested layouts restore incorrectly. Mitigation: accept only simple horizontal/vertical splits for MVP, document limitation.

3. **CLI commands execute out of order in batch scripts** — async RPC over socket, commands return before server completes. Causes `split-pane` to target wrong tab. Mitigation: use Lua API exclusively for session operations, avoid CLI for automation.

4. **`mux.spawn_window` with `domain` parameter creates 12+ duplicate tabs** — WezTerm bug. Mitigation: spawn without domain parameter, switch workspace first.

5. **Windows path extraction differs from Unix** — `file:///C:/path` vs `file:///Users/path` breaks cross-platform. Mitigation: platform-aware URI parsing using `wezterm.target_triple`.

## Implications for Roadmap

Based on research findings, the implementation should follow a foundation-first approach: establish daemon infrastructure and serialization before building user-facing features. This minimizes rework from API limitations discovered late.

### Phase 1: Daemon Infrastructure
**Rationale:** Foundation for all session persistence. Must be stable before building on top. Validates unix domain setup and mux server lifecycle.
**Delivers:** launchd plist, mux server auto-start on login, verification that panes survive GUI closure
**Addresses:** Core table-stakes feature (session persistence across disconnects)
**Avoids:** Pitfall #4 (mux domain spawning bugs) by testing daemon behavior early
**Research needs:** SKIP — launchd configuration is well-documented macOS pattern

### Phase 2: Layout Persistence (Capture)
**Rationale:** Need save capability before restore. Easier to test (just inspect JSON). Validates `panes_with_info()` and `get_current_working_dir()` APIs work as expected.
**Delivers:** Lua serializer module that captures current workspace state to JSON
**Addresses:** Layout save/restore feature (half: save only)
**Avoids:** Pitfall #1 (nil process names) and #2 (complex layouts) by discovering limitations early
**Uses:** WezTerm Lua API (`wezterm.mux`, `panes_with_info()`, `get_current_working_dir()`)
**Research needs:** LIGHT — API is documented, but need to validate nil-handling patterns

### Phase 3: Session Manager Core
**Rationale:** Core API that all UIs will use. No UI complexity yet. Establishes session CRUD operations and workspace-to-session mapping.
**Delivers:** Lua session manager module with create, list, save, delete functions
**Addresses:** Named session creation/listing features
**Implements:** Session Manager and Workspace Controller architecture components
**Research needs:** SKIP — straightforward Lua module design

### Phase 4: Shell CLI
**Rationale:** First user-facing interface. Test session operations without UI complexity. Validates that shell-to-Lua communication works.
**Delivers:** `wez-session` command with subcommands (new, list, save, kill)
**Addresses:** CLI wrapper interface (table stakes)
**Avoids:** Pitfall #3 (CLI command ordering) by using Lua API calls instead of CLI scripting
**Research needs:** SKIP — shell scripting is standard practice

### Phase 5: Layout Restoration
**Rationale:** Most complex part. Depends on CLI working for manual testing. Must handle async spawning, nil process names, and cross-platform paths.
**Delivers:** Session restoration from JSON (attach command), layout replay via `wezterm cli spawn`/`split-pane`
**Addresses:** Layout restore (second half), command restoration differentiator
**Avoids:** Pitfalls #1, #2, #3, #5 (all converge here)
**Research needs:** DEEP — complex interactions between APIs, platform differences, async behavior

### Phase 6: Fuzzy Picker
**Rationale:** First GUI component. Requires full save/restore working to be useful. Provides differentiation from basic CLI.
**Delivers:** Keybinding-triggered session picker using WezTerm's native `InputSelector`
**Addresses:** Fuzzy picker differentiator
**Avoids:** Pitfall #5 (tab switching frenzy) by using workspace switching instead of rapid tab changes
**Research needs:** LIGHT — `InputSelector` is documented, pattern exists in WezTerm examples

### Phase 7: On-Launch Picker
**Rationale:** Enhancement to workflow. Requires picker working. Low-risk polish feature.
**Delivers:** Show session picker on WezTerm launch (opt-in via config)
**Addresses:** Session picker on launch feature
**Research needs:** SKIP — hooks into `gui-startup` event, straightforward

### Phase Ordering Rationale

- **Daemon first** because session persistence is foundational — without it, everything else is pointless
- **Save before restore** because serialization is easier to test and debug (inspect JSON)
- **Core API before UIs** because CLI and picker both depend on session manager module
- **CLI before picker** because shell interface is simpler, better for testing session operations
- **Restoration is complex** because it's where all API limitations converge (nil handling, async spawning, cross-platform paths)
- **Picker at end** because it's polish on top of working core functionality

### Research Flags

**Phases needing deeper research during planning:**
- **Phase 5 (Layout Restoration):** Complex async behavior, platform path differences, process restoration logic all need prototyping. Multiple pitfalls converge here.

**Phases with standard patterns (skip research-phase):**
- **Phase 1 (Daemon):** launchd configuration is well-documented
- **Phase 3 (Session Manager):** Standard Lua module design
- **Phase 4 (Shell CLI):** Standard shell scripting
- **Phase 6 (Fuzzy Picker):** WezTerm `InputSelector` is documented
- **Phase 7 (On-Launch):** Straightforward event hook

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | WezTerm version verified (20240203), APIs confirmed available, launchd is standard macOS |
| Features | MEDIUM | Based on training data about tmux/zellij patterns, not verified with web research (tools unavailable) |
| Architecture | MEDIUM | High confidence in components, medium confidence in integration details (async behavior, process detection reliability) |
| Pitfalls | HIGH | Drawn from real-world session manager implementations and upstream bug reports |

**Overall confidence:** MEDIUM-HIGH

Confidence is reduced from HIGH due to:
- Web research tools unavailable during feature research (WebSearch failed, WebFetch unavailable)
- Some API behaviors need prototyping (async spawn timing, nil handling patterns)
- Cross-platform path extraction not tested on all platforms (Windows, Linux)

Confidence is elevated by:
- Direct verification of WezTerm APIs via local installation
- Multiple existing session manager implementations as reference
- Upstream bug reports confirming pitfalls
- User's WezTerm version confirmed compatible

### Gaps to Address

**During Planning:**
- **Process restoration strategy:** Decide which processes to auto-restore (just shells + nvim, or broader list?). Mitigation: start narrow, make configurable later.
- **Layout complexity limits:** Define acceptable layout patterns for MVP. Mitigation: test with 2-3 pane layouts, document limitations.
- **Cross-platform validation:** Ensure path extraction works on macOS/Linux/Windows. Mitigation: use `wezterm.target_triple` for platform detection, test on Linux VM.

**During Implementation:**
- **Async spawn behavior:** Prototype session restoration to understand timing. Mitigation: add sleep/synchronization if needed, or use Lua API exclusively.
- **Nil handling patterns:** Validate nil-checking for all API calls. Mitigation: defensive coding, fallback to defaults.

**Post-MVP:**
- **Complex layout support:** Revisit if users request it. Mitigation: wait for upstream to add split tree API.
- **Remote session support:** Defer until local sessions proven. Mitigation: design with extensibility in mind.

## Sources

### Primary (HIGH confidence)
- **WezTerm GitHub Documentation** (https://github.com/wez/wezterm/tree/main/docs) — Official Lua API docs, CLI commands, multiplexing setup
- **Local WezTerm Installation** (`wezterm --version`, `wezterm cli --help`) — Verified version 20240203 and available commands
- **danielcopper/wezterm-session-manager** (https://github.com/danielcopper/wezterm-session-manager) — Real-world implementation, issues document API limitations
- **WezTerm Issues** (#3237, #3994, #4121, #4408, #7368) — Upstream bug reports confirming pitfalls

### Secondary (MEDIUM confidence)
- **abidibo/wezterm-sessions** (https://github.com/abidibo/wezterm-sessions) — Alternative implementation, process restoration notes
- **macOS launchd Documentation** (Apple Developer, `man launchd.plist`) — Standard plist structure
- **Training Data** (January 2025 cutoff) — Terminal multiplexer patterns (tmux, zellij), shell scripting, JSON schema design

### Tertiary (LOW confidence)
- **Feature research (MEDIUM confidence):** Based on training data about tmux/zellij usage patterns — web research tools unavailable (WebSearch API errors, Brave Search requires API key)

---
*Research completed: 2026-03-14*
*Ready for roadmap: yes*
