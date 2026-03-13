---
title: "WezTerm Tab Lock"
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
- [x] Every metric has corresponding tracking events
- [x] No feature redundancy (check for duplicates)
- [x] No technical implementation details included
- [x] A new team member could understand this PRD

---

## Product Overview

### Vision

Users can mark important WezTerm tabs as "locked" so that CMD+W and CMD+SHIFT+W cannot accidentally close them, with a clear visual indicator showing which tabs are protected.

### Problem Statement

The current WezTerm configuration maps CMD+W to close pane and CMD+SHIFT+W to close tab — both without confirmation. During typical terminal workflows involving 5+ tabs (dev servers, SSH sessions, long-running processes), accidentally pressing CMD+W destroys the session with no way to recover. This is especially painful for SSH connections and processes that took time to set up.

### Value Proposition

A per-tab lock toggle gives the user selective protection for important tabs without adding friction to closing disposable ones. Unlike a global "always confirm" approach, tab lock only protects what matters — keeping the workflow fast for normal tabs while safeguarding critical sessions.

## User Personas

### Primary Persona: Terminal Power User

- **Demographics:** Developer, daily WezTerm user, 5-15 tabs open at any time, keyboard-driven workflow
- **Goals:** Keep critical tabs (SSH sessions, dev servers, long-running processes) safe from accidental closure while maintaining fast tab management for ephemeral tabs
- **Pain Points:** Muscle memory for CMD+W occasionally fires on the wrong tab. Losing an SSH session or dev server tab means re-establishing the connection and navigating back to the right directory/state. No recovery mechanism exists after accidental closure.

### Secondary Personas

Not applicable — this is a personal configuration feature for a single user.

## User Journey Maps

### Primary User Journey: Protecting a Critical Tab

1. **Awareness:** User opens a new SSH session or starts a long-running process and realizes they don't want to accidentally close it.
2. **Consideration:** N/A — the lock keybinding is the only option.
3. **Adoption:** User presses CMD+SHIFT+L to lock the current tab. A lock icon appears in the tab title confirming protection.
4. **Usage:** User continues working across multiple tabs. When they accidentally press CMD+W or CMD+SHIFT+W on a locked tab, the close is blocked and a toast notification reminds them the tab is locked.
5. **Retention:** User develops a habit of locking important tabs immediately after creating them. The visual indicator (lock icon) provides ongoing confidence.

### Secondary User Journey: Unlocking a Tab to Close It

1. User decides they're done with a previously locked tab.
2. User presses CMD+SHIFT+L to toggle the lock off. The lock icon disappears.
3. User presses CMD+W to close the tab normally.

## Feature Requirements

### Must Have Features

#### Feature 1: Toggle Tab Lock

- **User Story:** As a terminal user, I want to toggle a lock on the current tab so that I can protect it from accidental closure.
- **Acceptance Criteria (Gherkin Format):**
  - [x] Given a tab is unlocked, When I press CMD+SHIFT+L, Then the tab becomes locked and a lock icon appears in the tab title
  - [x] Given a tab is locked, When I press CMD+SHIFT+L, Then the tab becomes unlocked and the lock icon disappears from the tab title
  - [x] Given a newly opened tab, When I have not pressed CMD+SHIFT+L, Then the tab is unlocked by default

#### Feature 2: Block Close on Locked Tabs

- **User Story:** As a terminal user, I want CMD+W and CMD+SHIFT+W to be blocked on locked tabs so that I can't accidentally close important sessions.
- **Acceptance Criteria (Gherkin Format):**
  - [x] Given a tab is locked, When I press CMD+W (close pane), Then the pane is NOT closed and a toast notification appears saying the tab is locked
  - [x] Given a tab is locked, When I press CMD+SHIFT+W (close tab), Then the tab is NOT closed and a toast notification appears saying the tab is locked
  - [x] Given a tab is unlocked, When I press CMD+W, Then the pane closes normally (existing behavior)
  - [x] Given a tab is unlocked, When I press CMD+SHIFT+W, Then the tab closes normally (existing behavior)

#### Feature 3: Visual Lock Indicator

- **User Story:** As a terminal user, I want to see which tabs are locked at a glance so that I know which tabs are protected.
- **Acceptance Criteria (Gherkin Format):**
  - [x] Given a tab is locked, When I look at the tab bar, Then the tab title shows a lock icon prefix
  - [x] Given a tab is unlocked, When I look at the tab bar, Then the tab title shows no lock icon
  - [x] Given a locked tab is active or inactive, When I look at the tab bar, Then the lock icon is visible in both states

### Should Have Features

#### Feature 4: Shortcut Hint in Status Bar

- **User Story:** As a terminal user, I want the lock toggle shortcut to appear in the existing status bar hints so that I can remember the keybinding.
- **Acceptance Criteria (Gherkin Format):**
  - [x] Given the status bar hints are displayed, When I look at the right status area, Then I see the lock toggle shortcut listed alongside existing hints

### Could Have Features

None for this phase — the Must Have features fully address the problem.

### Won't Have (This Phase)

- **Bulk lock/unlock** — No "lock all tabs" or "unlock all tabs" action
- **Persistence across restarts** — Lock state resets when WezTerm exits (tab IDs change on restart anyway)
- **Confirmation override** — No "Are you sure?" dialog to force-close a locked tab (unlock first, then close)
- **Per-pane locking** — Lock operates at the tab level, not individual panes
- **Lock-on-create** — No auto-lock for new tabs; locking is always manual

## Detailed Feature Specifications

### Feature: Block Close on Locked Tabs

**Description:** When a tab is marked as locked, both the close-pane (CMD+W) and close-tab (CMD+SHIFT+W) keybindings are intercepted. If the current tab is locked, the close action is suppressed and the user receives a brief toast notification indicating the tab is protected and how to unlock it.

**User Flow:**
1. User presses CMD+W or CMD+SHIFT+W
2. System checks if the current tab is locked
3. If locked: toast notification appears ("Tab is locked. Unlock with CMD+SHIFT+L first."), no close action occurs
4. If unlocked: normal close behavior proceeds

**Business Rules:**
- Rule 1: Lock status is determined per-tab, not per-pane. All panes in a locked tab are protected.
- Rule 2: The toast notification should include the unlock keybinding so the user knows how to proceed.
- Rule 3: Unlocked tabs must behave exactly as they do today — zero friction added to the default workflow.

**Edge Cases:**
- Scenario 1: Last pane in a locked tab is CMD+W'd → Expected: Blocked, because closing the last pane would close the tab
- Scenario 2: Tab has multiple panes, CMD+W on a non-last pane in a locked tab → Expected: Blocked (lock protects ALL panes in the tab)
- Scenario 3: User locks a tab, then opens a new pane in it → Expected: New pane is also protected by the tab lock
- Scenario 4: Config reload while tabs are locked → Expected: Lock state preserved (in-memory state survives config reloads)

## Success Metrics

### Key Performance Indicators

- **Adoption:** User locks at least one tab per session when running important processes
- **Engagement:** Lock toggle used regularly (not just once and forgotten)
- **Quality:** Zero accidental tab closures on locked tabs; zero interference with unlocked tab workflow
- **Business Impact:** Eliminates time wasted re-establishing SSH sessions and restarting dev servers after accidental closure

### Tracking Requirements

N/A — this is a personal terminal configuration feature with no telemetry. Success is measured subjectively by the user's experience.

---

## Constraints and Assumptions

### Constraints

- All changes must live in `wezterm.lua` — no external scripts or shell integration
- Must work with the existing Catppuccin Mocha/Latte theme system (dark and light modes)
- Must not conflict with existing keybindings (see current keymap in wezterm.lua)
- CMD+SHIFT+L must not conflict with any existing WezTerm or macOS system shortcut

### Assumptions

- Tab IDs are stable for the lifetime of a WezTerm process (they are — assigned on creation, not reused)
- `wezterm.GLOBAL` persists across config reloads (documented WezTerm behavior)
- The user's WezTerm version supports `action_callback`, `GLOBAL`, `toast_notification`, and `format-tab-title` (all available in stable releases)

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| CMD+SHIFT+L conflicts with another binding | Medium | Low | Audit current keymap before implementation; confirmed no conflict in current config |
| Lock icon doesn't render in user's font | Low | Low | Use Nerd Font glyph; user already uses RobotoMono Nerd Font |
| State loss on config reload breaks locks | High | Low | Use `wezterm.GLOBAL` which explicitly survives reloads |
| Blocked close with no feedback is confusing | Medium | Medium | Toast notification explains the block and how to unlock |

## Open Questions

None — all questions resolved during brainstorming phase.

---

## Supporting Research

### Competitive Analysis

- **iTerm2:** Offers "Protected" sessions that prompt before closing. Similar concept, different execution (uses confirmation dialog instead of hard block).
- **tmux:** Has `set-option remain-on-exit on` which keeps panes alive after process exits, but doesn't prevent intentional close.
- **Zellij:** No tab lock feature, but has session persistence that makes accidental closes less painful.

### User Research

Based on direct user input: The primary pain point is losing SSH connections and long-running processes to muscle-memory CMD+W presses. The user prefers a hard block with visual feedback over a confirmation dialog.

### Market Data

N/A — personal configuration feature, not a commercial product.
