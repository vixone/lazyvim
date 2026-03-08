---
title: "Quick-Access Terminal (Frosted) + Stacked Pane Navigation"
status: draft
version: "2.0"
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

- [x] Problem is validated by evidence (user observation + Kitty docs verified)
- [x] Context → Problem → Solution flow makes sense
- [x] Every persona has at least one user journey
- [x] All MoSCoW categories addressed (Must/Should/Could/Won't)
- [x] No feature redundancy
- [x] No technical implementation details included
- [x] A new team member could understand this PRD

---

## Product Overview

### Vision

A distinct, frosted quick-access terminal appears and disappears at a single keypress — visually separate from the workspace, persistent across toggles, and instantly recognizable as "I am in the scratchpad, not the main workspace."

### Problem Statement

Two problems in the current Kitty config (spec 001):

1. **Overlay is not visually distinct.** The current overlay (`launch --type=overlay`) renders with the exact same background color and appearance as any regular pane. When it appears, it is not immediately obvious whether you are in the overlay or in a regular split pane. In Zellij, the floating pane is visually separate because it floats with clear framing and a slightly different surface. Kitty's current overlay has no such differentiation.

2. **Stacked panes have no ergonomic navigation.** When `Cmd+Shift+F` activates stack layout (single pane visible at a time), the only available navigation is `Cmd+arrows` — which silently no-ops in stack mode because there are no spatial neighbors. There is no way to cycle between hidden panes or pick a pane by name.

### Value Proposition

- **Visually grounded**: the overlay is immediately recognizable as a floating scratchpad — frosted/semi-transparent background distinguishes it from the opaque workspace panes
- **True toggle**: one keypress shows it; the same keypress hides it; the shell session is always preserved
- **Session never lost**: unlike the current overlay which is destroyed on dismiss, the quick-access terminal persists in the background
- **Stack layout becomes usable**: cycle keys and a visual pane picker make navigating hidden panes as fast as switching tabs

---

## User Personas

### Primary Persona: Developer migrating from Zellij

- **Role:** Software developer, daily terminal user
- **Technical expertise:** High — comfortable with config files, keybindings, terminal multiplexers
- **Goals:** Quick access to a scratchpad shell without losing context; clear visual feedback about which "layer" they are in; ergonomic stack-mode navigation
- **Pain Points:**
  - Current overlay looks identical to every other pane — no visual cue "you are floating"
  - Stack layout panes are unreachable after creation without spatial arrow keys that don't work in stack mode

---

## User Journey Maps

### Primary User Journey: Frosted scratchpad access

1. **Trigger:** Developer is in a tiled pane (editor, logs) and needs a quick shell command
2. **Action:** Presses `Cmd+F` — a frosted, semi-transparent terminal appears over the workspace; the opacity difference makes it immediately clear "I am in the scratchpad"
3. **Work:** Runs commands; the transparent background gives a subtle sense of floating above the workspace
4. **Dismiss:** Presses `Cmd+F` — scratchpad hides, workspace is visible again, full opacity restored
5. **Return:** Presses `Cmd+F` later — scratchpad reappears with full session state (directory, history, running processes intact)

### Secondary User Journey: Stacked pane navigation

1. **Setup:** Developer has 3–4 panes and uses `Cmd+Shift+F` to enter focus/stack mode
2. **Cycle:** Presses a dedicated window-cycle key to move to the next hidden pane
3. **Visual pick:** When disoriented, presses a visual-picker key — numbered overlays appear on each pane; developer presses the number to jump directly
4. **Exit stack:** `Cmd+Shift+F` returns to tiled layout with all panes visible

---

## Feature Requirements

### Must Have Features

#### Feature 1: Frosted Quick-Access Terminal (Toggle)

- **User Story:** As a developer, I want to press one key to show or hide a semi-transparent scratchpad terminal so that I can instantly tell I'm in the overlay and the session is always preserved.

**Acceptance Criteria:**
- [ ] Given no scratchpad is visible, When the user presses `Cmd+F`, Then a frosted (semi-transparent) terminal appears over the workspace
- [ ] Given the scratchpad is visible, When the user presses `Cmd+F`, Then the scratchpad hides and the workspace is fully visible again
- [ ] Given the user ran commands in the scratchpad and then hid it, When the user presses `Cmd+F` again, Then the scratchpad reappears with full session state intact
- [ ] Given the scratchpad is open, The background of the scratchpad terminal MUST be visually different from opaque panes (semi-transparent or distinctly colored), making it immediately clear the user is in the overlay
- [ ] Given the user presses `Ctrl+D` or types `exit` inside the scratchpad, Then the session ends and the scratchpad closes; next `Cmd+F` starts a fresh session

#### Feature 2: Stacked Pane Cycle Navigation

- **User Story:** As a developer in stack layout, I want cycle keys to move through hidden panes so that I am not blocked by the no-op arrow behavior in stack mode.

**Acceptance Criteria:**
- [ ] Given stack layout is active, When the user presses the next-window key, Then the next pane becomes visible and focused
- [ ] Given stack layout is active, When the user presses the previous-window key, Then the previous pane becomes visible and focused
- [ ] Cycle keys MUST NOT conflict with existing tab navigation (`Cmd+Shift+[/]`)
- [ ] Given the user is on the last pane, When pressing next, Then focus wraps to the first pane

#### Feature 3: Visual Pane Picker

- **User Story:** As a developer with multiple hidden panes, I want a visual numbered picker so that I can jump directly to any pane without cycling through all of them.

**Acceptance Criteria:**
- [ ] Given the user presses the picker key, Then each accessible pane is labeled with a number overlaid on screen
- [ ] Given the picker is shown, When the user presses a number, Then focus immediately switches to that pane
- [ ] Given the picker is shown, When the user presses `Escape`, Then the picker dismisses with no change
- [ ] The picker key MUST NOT conflict with tab navigation, layout cycling, or the scratchpad toggle

### Should Have Features

- Scratchpad opens in current working directory (inherits `cwd` from active pane)
- Scratchpad has a visible title ("scratchpad") so the visual picker labels it clearly
- The frosted opacity level is tunable in config (not hardcoded)

### Could Have Features

- `hide_on_focus_loss` — scratchpad auto-hides when focus moves to another window
- Custom scratchpad size (e.g., 80% width, 60% height, centered) via `quick-access-terminal.conf`
- A distinct background tint color (e.g., slight purple cast) on top of the transparency to reinforce the "floating" aesthetic

### Won't Have (This Phase)

- Multiple simultaneous scratchpad instances — one is sufficient
- Animated transitions — not supported by Kitty
- Embed/float conversion of arbitrary existing panes — Kitty architecture does not support this
- External multiplexer (tmux/zellij) inside the scratchpad — overcomplicated for a simple scratchpad

---

## Detailed Feature Specifications

### Feature: Frosted Quick-Access Terminal

**Description:** Replaces the current `launch --type=overlay` binding with `kitten quick_access_terminal`, Kitty's built-in Quake-style toggle terminal (added in v0.42.0, confirmed available in installed v0.45.0). The kitten natively supports: toggle behavior, session persistence between toggles, and `background_opacity 0.85` (semi-transparent) by default. Configuration lives in `quick-access-terminal.conf` in the kitty config directory.

**User Flow:**
1. User presses `Cmd+F` → scratchpad appears (frosted, semi-transparent)
2. User works in scratchpad shell
3. User presses `Cmd+F` → scratchpad hides (session preserved)
4. User presses `Cmd+F` → scratchpad reappears at same state
5. User presses `Ctrl+D` → session ends; next `Cmd+F` starts fresh

**Business Rules:**
- Rule 1: `Cmd+F` is the single toggle key (replaces existing `launch --type=overlay` binding)
- Rule 2: The scratchpad must be visually distinguishable from regular panes at a glance
- Rule 3: Session persists between hide/show cycles (only ends on explicit `exit`/`Ctrl+D`)
- Rule 4: Only one instance of the scratchpad runs at a time (enforced by kitten `--instance-group`)

**Edge Cases:**
- User presses `Cmd+F` rapidly → idempotent, no duplicate windows
- Scratchpad process dies unexpectedly → next `Cmd+F` starts fresh session
- User has no macOS "Quick access to kitty" service configured → `Cmd+F` in kitty.conf keybinding is sufficient (macOS system shortcut is optional, not required)

---

## Success Metrics

### Key Performance Indicators

Personal developer tooling — qualitative validation:

- **Visual clarity:** User can immediately identify "I am in the scratchpad" from background opacity alone, without needing to read a title or check a status bar
- **Zero context loss:** Shell session is never accidentally destroyed by pressing `Cmd+F` to dismiss
- **Stack usability:** User can navigate between 4 stacked panes in ≤2 keystrokes

---

## Constraints and Assumptions

### Constraints

- **Kitty v0.45.0** is installed — `quick-access-terminal` kitten requires v0.42.0+ (confirmed satisfied)
- **`allow_remote_control yes`** must remain set in `kitty.conf` (already set in spec 001)
- **`Cmd+Shift+[/]`** is already bound to tab navigation — window cycle keys must use a different combination
- **macOS `Cmd+F` system shortcut**: Kitty's `Cmd+F` keybinding takes precedence inside Kitty; no system conflict expected

### Assumptions

- The user runs Kitty as the active terminal (not inside another multiplexer)
- `quick-access-terminal.conf` can live in `~/.config/kitty/` alongside `kitty.conf`
- `focus_visible_window` (built-in Kitty action) is available — confirmed in installed docs
- The `edge center-sized` option in `quick-access-terminal.conf` centers the scratchpad on screen

---

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `kitten quick_access_terminal` requires macOS system shortcut setup | Medium | Low | `Cmd+F` can be bound directly in `keybindings.conf` without macOS service setup |
| `background_opacity` on macOS may not show through to desktop as expected | Low | Low | Test during E2E; fall back to a distinct tint color if opacity doesn't render cleanly |
| Chosen window-cycle keys conflict with existing `keybindings.conf` bindings | Medium | Medium | Full conflict audit in SDD against current keybindings.conf |
| `focus_visible_window` visual overlay is hard to read on Tokyonight Night | Low | Low | Test during E2E; theme provides good contrast generally |

---

## Open Questions

- [ ] Which key pair for `next_window` / `previous_window`? Candidates: `Cmd+Opt+[/]`, `Cmd+[/]` — decide in SDD
- [ ] Which key for visual picker (`focus_visible_window`)? Candidate: `Cmd+;` — confirm no conflict in SDD
- [ ] Scratchpad size: default (full-width top-anchored) or centered? `edge center-sized` vs `edge top` — decide in SDD

---

## Supporting Research

### Competitive Analysis

**Zellij floating pane (user's actual config)**
- Toggle: `Alt+F` → `ToggleFloatingPanes` (bidirectional)
- Persistence: YES — session survives hide/show
- Visual: renders on top of tiled layout, background panes visible

**Kitty `quick-access-terminal` kitten (v0.42.0+, available in v0.45.0)**
- Toggle: run `kitten quick_access_terminal` to show; same command hides it
- Persistence: YES — hidden window, session preserved
- Visual: `background_opacity 0.85` by default = semi-transparent / frosted
- Configurable: `quick-access-terminal.conf` for size, opacity, edge, color overrides
- Directly addresses both problems: toggle AND visual distinction

**Current spec 001 overlay (being replaced)**
- `launch --type=overlay --title=overlay zsh`
- NOT a toggle — new window every press
- NOT persistent — destroy on dismiss
- NOT visually distinct — same colors as all panes

### User Research

User stated: "the problem I want to solve is that I'm used to Zellij and in Kitty overlay it's not obvious where I am — maybe making the overlay transparent or something." The `quick-access-terminal` kitten directly solves both dimensions: toggle behavior AND frosted transparency.

### Market Data

N/A — personal developer tooling.
