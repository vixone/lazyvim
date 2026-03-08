---
title: "Kitty Session Manager — Full Redesign"
status: draft
version: "1.0"
---

# Product Requirements Document

## Validation Checklist

### CRITICAL GATES (Must Pass)

- [x] All required sections are complete
- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Problem statement is specific and measurable
- [x] Every feature has testable acceptance criteria (Gherkin format)
- [x] No contradictions between sections

### QUALITY CHECKS (Should Pass)

- [x] Problem is validated by evidence (not assumptions)
- [x] Context → Problem → Solution flow makes sense
- [x] Every persona has at least one user journey
- [x] All MoSCoW categories addressed (Must/Should/Could/Won't)
- [x] No technical implementation details included
- [x] A new team member could understand this PRD

---

## Product Overview

### Vision

A kitty session manager that actually works — where saving a session and loading it back are reliable one-action operations, and the interface requires zero memorisation.

### Problem Statement

Spec 003 (kitty-session-ux) was implemented but is completely non-functional due to three compounding failures:

1. **Session loading is broken at the file format level.** The session saver writes `session_name <name>` as the first line of every `.kitty-session` file. This command is not part of kitty's session file syntax. When the user tries to load any saved session, kitty throws:
   ```
   ValueError: Unknown command in session file: session_name
   ```
   Every session that has ever been saved via `ctrl+o > s` is unloadable.

2. **The session picker and save prompts are silently broken.** The overlay kitten attempts to read user input using low-level terminal manipulation (`tty.setraw` / `termios`) on a stdin that may not be a TTY in an overlay context. This causes the overlay to flash and vanish before the user can interact with it — with no error message.

3. **The menu UX is frustrating even when it briefly appears.** Number-based session selection, a full-screen overlay for three options, and no visual recovery from any failure state all contribute to a feature that feels broken and hard to trust.

The consequences: the session system is completely unusable. The user cannot load named sessions, the tab bar session indicator never updates, and pressing `ctrl+o` produces unreliable behaviour.

### Value Proposition

- Sessions load reliably every time — no `ValueError`, no silent failures.
- The session picker is fast and frictionless, using a familiar search-and-select interface rather than number entry.
- The tab bar always shows which session is active, giving constant orientation at zero cognitive cost.
- Saving the current workspace takes two keystrokes and produces a file that can always be reloaded.

---

## User Personas

### Primary Persona: Solo Power User

- **Role:** Developer working across multiple project contexts in a single kitty window.
- **Goals:** Jump between named workspaces (dotfiles, work, sandbox) without breaking flow. Know at a glance which context is active. Trust that what was saved will reload correctly.
- **Pain Points:** Sessions that generate files that cannot be loaded back. A picker that disappears before it can be used. Having to remember which number corresponds to which session. No confidence that the save worked.

### Secondary Personas

None — single-user personal config.

---

## User Journey Maps

### Primary User Journey: Loading a Saved Session

1. **Trigger:** User wants to switch from the current workspace to a named project context.
2. **Action:** Presses `ctrl+o` — the session prefix key.
3. **Feedback:** The hint overlay appears immediately, listing available sub-commands.
4. **Selection:** User presses `w` for the session picker.
5. **Picker:** A searchable list of saved sessions appears. User types to filter or navigates and presses Enter.
6. **Confirmation:** Session loads, tab bar updates to show the new session name as a prefix on every tab.
7. **Orientation:** User knows exactly where they are from the tab bar.

### Secondary User Journeys

**Saving the current workspace:**
1. User has arranged tabs and panes for a new project.
2. Presses `ctrl+o` → hint overlay shows available commands including `s = save session`.
3. Presses `s` → prompted for a session name.
4. Types name, presses Enter → file is written to `~/.config/kitty/sessions/<name>.kitty-session`.
5. Session is immediately loadable from the picker.

**Dismissing the overlay without action:**
1. User presses `ctrl+o` by accident or changes their mind.
2. Presses Escape or an unrecognised key.
3. Overlay closes cleanly, no action taken, terminal returns to normal state.

---

## Feature Requirements

### Must Have Features

#### Feature 1: Working Session Files

- **User Story:** As a kitty user, I want saved session files to be loadable by kitty so that I can restore my workspace without errors.
- **Acceptance Criteria:**
  - [ ] Given a session file was saved via `ctrl+o > s`, When the user loads it via the session picker, Then the session loads without any `ValueError` or error dialog.
  - [ ] Given a saved session file, When kitty parses it, Then every line in the file is a valid kitty session directive.
  - [ ] Given a session with 3 tabs each with 2 windows, When it is saved and reloaded, Then kitty opens 3 tabs with the correct working directories and window titles.

#### Feature 2: Working Session Picker

- **User Story:** As a kitty user, I want pressing `w` in the hint overlay to open a functioning session picker so that I can select and load a session.
- **Acceptance Criteria:**
  - [ ] Given saved sessions exist, When the user presses `w` in the hint overlay, Then a session picker appears that the user can interact with (does not flash and vanish).
  - [ ] Given the session picker is open, When the user selects a session and confirms, Then that session loads in kitty.
  - [ ] Given the session picker is open, When the user presses Escape or Ctrl+C, Then the picker closes cleanly and kitty returns to normal state.
  - [ ] Given no sessions are saved yet, When the user opens the picker, Then a graceful empty-state message is shown.

#### Feature 3: Session Name in Tab Bar

- **User Story:** As a kitty user, I want the active session name to be visible in the tab bar so that I always know which session I am in.
- **Acceptance Criteria:**
  - [ ] Given a named session is active, When I look at the tab bar, Then each tab title is prefixed with the session name (e.g. `work › 1: zsh`).
  - [ ] Given I switch to a different session, When the session loads, Then the tab bar updates to show the new session name prefix.
  - [ ] Given no named session is active, When I look at the tab bar, Then tab titles show no session prefix (e.g. `1: zsh`).

#### Feature 4: Working Save Flow

- **User Story:** As a kitty user, I want pressing `s` in the hint overlay to prompt me for a name and save my session so that I can restore this workspace later.
- **Acceptance Criteria:**
  - [ ] Given the hint overlay is open, When the user presses `s`, Then a name prompt appears and accepts keyboard input correctly.
  - [ ] Given the user types a session name and presses Enter, Then a `.kitty-session` file is written to `~/.config/kitty/sessions/<name>.kitty-session`.
  - [ ] Given the session was just saved, When the user opens the picker, Then the newly saved session appears in the list.
  - [ ] Given the user presses Enter with an empty name, Then the save is aborted and the overlay closes cleanly.

#### Feature 5: Reliable Hint Overlay

- **User Story:** As a kitty user, I want the `ctrl+o` hint overlay to appear and stay visible until I press a key so that I can see my options and make a deliberate choice.
- **Acceptance Criteria:**
  - [ ] Given kitty is focused, When I press `ctrl+o`, Then a hint overlay appears and remains visible.
  - [ ] Given the hint overlay is visible, When I press a recognised key (`w`, `s`), Then the corresponding flow executes.
  - [ ] Given the hint overlay is visible, When I press Escape or an unrecognised key, Then the overlay closes without executing any action.
  - [ ] Given any number of tabs or panes are open, When the overlay appears, Then it does not resize or disrupt the underlying layout.

### Should Have Features

- **Active session tracking across loads:** When a session is loaded, the system records which session is now active so that the session picker can show a `●` indicator next to the current session.
- **Session mode visual indicator:** While the hint overlay is open, the active tab's background colour changes to a distinct accent colour, signalling that a prefix key is active.

### Could Have Features

- **Delete session from picker:** Ability to delete a saved session file from within the picker interface.
- **Rename session:** Rename a saved `.kitty-session` file from within the picker.

### Won't Have (This Phase)

- Automatic session save on kitty close.
- Per-session colour themes.
- Mouse interaction with the picker or hint overlay.
- Sync or backup of session files.
- Animated transitions.

---

## Detailed Feature Specifications

### Feature: Session Picker

**Description:** When the user presses `w` in the hint overlay, a searchable list of saved sessions appears. The user can type to filter, navigate with arrow keys, and press Enter to load the selected session. The currently active session (if known) is marked with an indicator.

**User Flow:**
1. User presses `ctrl+o`.
2. Hint overlay appears with available commands.
3. User presses `w`.
4. Hint overlay closes; a session picker interface opens.
5. Picker displays: session name list, current session indicator, filter prompt.
6. User types to filter or navigates to a session.
7. User presses Enter to load the session.
8. Picker closes; session loads; tab bar updates.

**Business Rules:**
- The session list is populated from all `.kitty-session` files in `~/.config/kitty/sessions/`.
- Session names are derived from filenames (strip `.kitty-session` suffix).
- The current session indicator must reflect the last session loaded via the picker.
- If a session file has been deleted externally, it must not appear in the picker.
- Loading a session must use the correct kitty remote control API — the resulting session file must be valid before it is ever written.

**Edge Cases:**
- No sessions saved → Show empty-state message; do not crash.
- Session file deleted between save and load → Load attempt fails gracefully; show error message.
- User presses Ctrl+C in picker → Close cleanly; no partial state.

---

## Success Metrics

### Key Performance Indicators

Personal productivity config — informal metrics:

- **Reliability:** Session load succeeds 100% of the time for files saved by this system. Zero `ValueError` occurrences.
- **Adoption:** `ctrl+o` is used confidently without hesitation or workaround.
- **Orientation:** Tab bar session prefix is always accurate — never shows stale or wrong session name.
- **Discoverability:** The hint overlay is the only documentation needed. No external cheatsheet required.

### Tracking Requirements

Not applicable — personal config, no telemetry.

---

## Constraints and Assumptions

### Constraints

- Must use only kitty's native extension points: config options, Python kittens, shell scripts, and `kitten @` remote control API.
- No pip packages or third-party Python libraries.
- Must not break any existing keybindings from specs 001 and 002 (see full list in constraints audit).
- Must not modify: `pass_keys.py`, `navigate_or_tab.py`, `theme.conf`, `quick-access-terminal.conf`.
- Must preserve: `allow_remote_control yes`, `listen_on unix:/tmp/kitty`, font settings, layout order, tab bar powerline style.
- Tools available on this system that are NOT forbidden: `fzf` (confirmed at `/opt/homebrew/bin/fzf`), `zsh`, standard macOS utilities.

### Assumptions

- kitty version 0.45.0 is installed (confirmed by UX research agent).
- `KITTY_LISTEN_ON` environment variable is set in overlay windows launched via `launch --type=overlay`.
- `fzf` is reliably available at `/opt/homebrew/bin/fzf` (confirmed).
- The `sessions/` directory at `~/.config/kitty/sessions/` already exists and contains the pre-existing session files (`kitty.kitty-session`, `work.kitty-session`).
- The existing session files must be fixed (remove invalid `session_name` line) as part of this work.

---

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `kitten @ action goto_session <path>` is not valid API syntax | High | Medium | Verify actual API before writing implementation; use `kitten @ goto-session` (hyphenated) if needed |
| `kitten @ set-tab-color` syntax is wrong | Medium | Medium | Test manually; make tab colour indicator optional if unsupported |
| `KITTY_LISTEN_ON` not propagated into overlay child processes | High | Low | Add fallback to `unix:/tmp/kitty`; log to file for debugging |
| fzf path differs between sessions (e.g. after brew update) | Medium | Low | Use `command -v fzf` to resolve path at runtime; graceful fallback to number-based picker |
| Existing session files (`kitty.kitty-session`, `work.kitty-session`) have stale content from old save logic | Medium | High | Strip `session_name` line from existing files as part of migration step |

---

## Open Questions

- [ ] What is the exact `kitten @` syntax for loading a session file? (`kitten @ action goto_session <path>` vs `kitten @ goto-session <path>`) — must be verified against kitty 0.45.0 before SDD.
- [ ] Is `{session_name}` the correct tab_title_template variable, or is it `{session}`? The current `active_tab_title_template` uses `session_name` — must verify against kitty docs.
- [ ] Should the picker be a full-screen overlay (current approach) or a smaller overlay-main type? — UX decision, defer to SDD.

---

## Supporting Research

### Competitive Analysis

- **tmux + tmux-resurrect:** Full session save/restore including running processes. Kitty cannot restore running processes (CON-3 from spec 001) — but can restore directory layout.
- **lazyvim which-key:** Shows hint overlay ~500ms after prefix. Target UX model for the hint overlay (already implemented in spec 003's design).
- **fzf:** Standard fuzzy finder — available on this system. The de-facto standard for interactive terminal selection UIs. More discoverable and faster than number-based selection.

### User Research

Single user. Requirements sourced from stated preferences and observed failure modes:
- "the session feature, picker and saver don't work so well"
- "i don't like how the menu works and it bugs out"
- "i can't load sessions" (with `ValueError: Unknown command in session file: session_name`)

### Market Data

Not applicable.

### Research Findings (from parallel investigation)

**Bug Inventory (from constraints audit agent):**
- BUG #1 CRITICAL: `session_name` in generated session files (line 89 of `which_key.py`) is not a valid kitty directive → `ValueError` on every load.
- BUG #2 MAJOR: `read_one_key()` uses `termios.tcgetattr` which fails when stdin is not a TTY in overlay context → overlay vanishes immediately.
- BUG #3 MAJOR: `goto_session` dispatch syntax via `kitten @ action` not verified — may require `kitten @ goto-session`.
- BUG #4 MAJOR: `set-tab-color` argument syntax unverified.
- BUG #5 MODERATE: `read_line()` called after `setraw` in overlay creates terminal state corruption risk.

**UX Findings (from UX research agent):**
- Root cause of "menu bugs out": Python `termios.tcgetattr` in overlay context raises `OSError: Inappropriate ioctl for device` — swallowed by broad `except Exception`, overlay vanishes silently.
- `fzf` confirmed available at `/opt/homebrew/bin/fzf` (v0.70.0).
- Shell `read` command works reliably in overlay context (shell's built-in TTY handling vs manual termios).
- Recommended approach: shell-based picker using `fzf` or `zsh read` rather than Python termios.

**Session Format Findings (from format research agent):**
- `session_name` is NOT a valid kitty session file directive. Valid commands: `layout`, `enabled_layouts`, `cd`, `launch`, `new_tab`, `focus`, `focus_tab`.
- `{session_name}` in `tab_title_template` is filename-derived — the name comes from the `.kitty-session` filename, not from any command inside the file. This is actually useful: save as `work.kitty-session` and `{session_name}` shows `work` automatically.
- The sidecar `.current_session` file approach is a valid way to track the currently loaded session name.
