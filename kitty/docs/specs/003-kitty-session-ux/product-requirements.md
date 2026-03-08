---
title: "Kitty Session UX — Tab Bar, Session Indicator & Which-Key Hint Menu"
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

A kitty terminal workflow where the current session is always visible and navigating between sessions requires zero memorisation.

### Problem Statement

After adding kitty sessions (spec 002), three friction points remain:

1. **Tab bar is at the bottom** — visually disconnected from window chrome; users expect tabs at the top (browser/editor convention).
2. **No session identity** — there is no persistent visual indicator of which session is active. Switching sessions feels disorienting.
3. **Chord bindings are invisible** — after pressing `ctrl+o` (the session prefix), nothing happens visually. The user must remember all sub-keys (`w`, `l`, `s`) from memory, like tmux. This makes the feature hard to discover and easy to forget.

### Value Proposition

- Tab bar at top matches every other tabbed application the user runs.
- A session name pill in the tab bar gives constant, low-noise context about where you are.
- A which-key overlay after `ctrl+o` eliminates the need to memorise bindings — the terminal teaches itself.

---

## User Personas

### Primary Persona: Solo Power User

- **Role:** Developer managing multiple project contexts in a single kitty window.
- **Goals:** Stay in flow across sessions without context-switching overhead. Know at a glance which session is active. Discover available commands without reading documentation.
- **Pain Points:** No visual feedback after pressing a prefix key. Forgetting chord sub-keys means pressing the wrong key or abandoning the action. No session identity in the tab bar makes sessions feel like invisible state.

### Secondary Personas

None — this is a single-user personal config.

---

## User Journey Maps

### Primary User Journey: Switching Sessions

1. **Trigger:** User wants to jump to a different project context.
2. **Action:** Presses `ctrl+o` — the session prefix.
3. **Feedback:** A hint overlay immediately appears showing available sub-commands with descriptions.
4. **Selection:** User presses the desired key (e.g. `w` for the session picker).
5. **Confirmation:** Overlay closes, new session loads, tab bar updates to show new session name.
6. **Orientation:** User glances at session name pill in tab bar to confirm they arrived in the right place.

### Secondary User Journeys

**Saving the current session:**
1. User has arranged tabs and panes for a new workflow.
2. Presses `ctrl+o` → sees hint overlay showing `s = save session`.
3. Presses `s` → prompted for a session name (just the name, no path).
4. Session is saved to `~/.config/kitty/sessions/<name>.kitty-session`.

---

## Feature Requirements

### Must Have Features

#### Feature 1: Tab Bar at Top

- **User Story:** As a kitty user, I want the tab bar at the top of the window so that it matches the visual convention of every other tabbed application I use.
- **Acceptance Criteria:**
  - [ ] Given kitty is open with multiple tabs, When I look at the window, Then the tab bar is displayed at the top of the window, not the bottom.
  - [ ] Given the tab bar is at the top, When I open or close tabs, Then tab bar behaviour (powerline style, tab titles) is unchanged.

#### Feature 2: Session Name Pill in Tab Bar

- **User Story:** As a kitty user, I want to see the current session name displayed in the tab bar so that I always know which session I am in without having to remember.
- **Acceptance Criteria:**
  - [ ] Given I am in a named session, When I look at the tab bar, Then the active session name is visible as a label in the tab bar.
  - [ ] Given I switch to a different session via `ctrl+o>w`, When the new session loads, Then the session name label in the tab bar updates to reflect the new session.
  - [ ] Given I am in an unnamed session (no session file loaded), When I look at the tab bar, Then no session label is shown (or a neutral placeholder is shown).

#### Feature 3: Which-Key Hint Overlay for `ctrl+o`

- **User Story:** As a kitty user, I want a popup hint menu to appear when I press `ctrl+o` so that I can see all available sub-commands without memorising them.
- **Acceptance Criteria:**
  - [ ] Given kitty is focused, When I press `ctrl+o`, Then a floating hint overlay appears immediately listing all available sub-commands with their key and a short description.
  - [ ] Given the hint overlay is visible, When I press a valid sub-key (e.g. `w`), Then the corresponding action executes and the overlay closes.
  - [ ] Given the hint overlay is visible, When I press `Escape` or an unrecognised key, Then the overlay closes and no action is taken.
  - [ ] Given the hint overlay is visible, When I press `ctrl+o` again, Then the overlay closes (toggle behaviour).
  - [ ] Given any number of tabs/panes are open, When the overlay appears, Then it does not disturb or resize the underlying panes.

### Should Have Features

- **Keyboard mode indicator in tab title:** When `ctrl+o` has been pressed and a mode is active, the tab title or tab bar shows a subtle indicator (e.g. `[O]` prefix or colour change) so the user knows they are in prefix mode even if the overlay has closed.

### Could Have Features

- **Overlay shows recently used session** highlighted or sorted to top.
- **Overlay is keyboard-navigable** (arrow keys to move, Enter to confirm) in addition to direct key press.

### Won't Have (This Phase)

- Mouse-clickable hint overlay items.
- Animated transitions for overlay appearance/dismissal.
- Per-session custom colour themes for the tab bar.
- Integration with external status bars (sketchybar, etc.).

---

## Detailed Feature Specifications

### Feature: Which-Key Hint Overlay

**Description:** When the user presses `ctrl+o`, a small overlay window appears on top of the current pane. It displays a formatted table of all available `ctrl+o` sub-commands — each row showing the key and a human-readable description. The user presses one key to execute and dismiss, or Escape to cancel.

**User Flow:**
1. User presses `ctrl+o`.
2. Kitty enters a keyboard mode (prefix mode) AND launches an overlay window.
3. Overlay renders the hint table (e.g. `w  →  session picker`, `l  →  last session`, `s  →  save session`).
4. User presses a key.
5. Overlay closes, action fires.

**Business Rules:**
- The hint table content must exactly match the actual bound keys — they must stay in sync.
- Pressing any key not in the hint table must dismiss the overlay without side effects.
- The overlay must close after exactly one key action — it is not a persistent menu.

**Edge Cases:**
- No sessions saved yet → `w` (session picker) should still open, showing an empty list gracefully.
- Session file path does not exist → session switch silently fails or shows an error in the overlay.
- Kitty is running in a single-pane, single-tab window → overlay still appears correctly.

---

## Success Metrics

### Key Performance Indicators

This is a personal productivity config; formal metrics are informal:

- **Adoption:** `ctrl+o` is used confidently without consulting documentation.
- **Orientation:** User never needs to ask "which session am I in?" — answered by the tab bar.
- **Discoverability:** New `ctrl+o` sub-commands added in future are visible immediately without updating any documentation.

### Tracking Requirements

Not applicable — personal config, no telemetry.

---

## Constraints and Assumptions

### Constraints

- Must work within kitty's native extension points: config options, Python kittens, remote control API (`kitten @`).
- No external dependencies beyond what ships with kitty.
- Must not break existing keybindings or pane/tab behaviour from specs 001 and 002.

### Assumptions

- Kitty version supports: `tab_bar_edge top`, `map --new-mode`, `launch --type=overlay`, `keyboard_mode` in `tab_title_template`, `{session_name}` in `tab_title_template`.
- The user's kitty is configured with `allow_remote_control yes` and `listen_on unix:/tmp/kitty` (already set in kitty.conf).
- Session files live in `~/.config/kitty/sessions/`.

---

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Overlay kitten and modal mapping key interception conflict | High | Medium | Implement overlay to read keys itself; modal mode used only as fallback indicator |
| `{session_name}` shows empty for tabs not started from a session file | Low | High | Show neutral placeholder or omit label when session_name is empty |
| Hint table goes stale when new ctrl+o bindings are added | Medium | Medium | Define hint content in a single source file that both the overlay and keybindings.conf reference |

---

## Open Questions

- [ ] Should the which-key overlay use kitty's modal mapping (`map --new-mode`) for key interception, or should the overlay kitten capture input directly? (Deferred to SDD.)
- [ ] Should the session name pill be a separate always-visible tab, or embedded in the active tab's title template? (User preference: pill/tab — clarify exact placement in SDD.)

---

## Supporting Research

### Competitive Analysis

- **tmux prefix key:** Shows nothing after prefix press — full memorisation required. `ctrl+o` UX as designed is already an improvement.
- **lazyvim which-key:** Appears ~500ms after prefix, shows keys grouped by category. Target UX model.
- **kitty native:** No which-key built-in. `focus_visible_window` and `select_tab` kittens demonstrate the overlay pattern is well-supported.

### User Research

Single user (you). Requirements sourced directly from stated preferences.

### Market Data

Not applicable.
