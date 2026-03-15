# Requirements: WezTerm Session Manager

## v1 Requirements

### Infrastructure

| ID | Requirement | Priority |
|----|-------------|----------|
| REQ-01 | Always-on mux daemon via launchd that survives WezTerm window closes | P1 |
| REQ-08 | Shell script + Lua module architecture -- zero external dependencies | P1 |
| REQ-10 | Integration with existing wezterm.lua config (theme, smart-splits, tab lock, hints) | P1 |

### Persistence

| ID | Requirement | Priority |
|----|-------------|----------|
| REQ-09 | Session data stored as JSON files for portability and version control | P1 |
| REQ-03 | Layout save/restore: tabs, pane splits, working directories persisted to JSON | P1 |
| REQ-04 | Running command capture and restoration (e.g., `claude`, `nvim`, `npm dev`) | P1 |

### Session Management

| ID | Requirement | Priority |
|----|-------------|----------|
| REQ-02 | Named sessions (workspaces) with create, list, switch, and delete operations | P1 |
| REQ-07 | CLI wrapper (`wez-session`) with subcommands: new, list, attach, save, kill | P1 |

### User Interface

| ID | Requirement | Priority |
|----|-------------|----------|
| REQ-05 | Fuzzy session picker accessible via keybinding for quick switching | P1 |
| REQ-06 | Delete mode in fuzzy picker -- Tab toggles to delete, with confirmation | P1 |

## Out of Scope (v1)

- tmux or zellij dependency -- native WezTerm only
- Remote session management (SSH domains) -- local only
- Multi-machine session sync -- per-machine, git-synced if desired
- GUI session management app -- CLI + in-terminal picker only
- Automatic Claude Code conversation state persistence -- re-launch in CWD, user runs `/resume`

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| REQ-01 | Phase 1 | Complete |
| REQ-08 | Phase 1 | Complete |
| REQ-10 | Phase 1 | Complete |
| REQ-09 | Phase 2 | Complete |
| REQ-02 | Phase 3 | Pending |
| REQ-07 | Phase 4 | Complete |
| REQ-03 | Phase 5 | Complete |
| REQ-04 | Phase 5 | Complete |
| REQ-05 | Phase 6 | Complete |
| REQ-06 | Phase 7 | Pending |

---
*Created: 2026-03-14*
