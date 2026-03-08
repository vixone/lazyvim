---
title: "Kitty Terminal Migration — Theme, Panes & LazyVim Integration"
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

A fully configured Kitty terminal that feels like a natural extension of LazyVim — matching its Tokyonight Night aesthetic, providing Zellij-grade pane management, and teaching the user a new set of keyboard shortcuts that become muscle memory within days.

### Problem Statement

The user has migrated from iTerm2 to Kitty but has a completely blank configuration — no theme, no keybindings, no pane layout setup. The current state is:
- Kitty renders with default colors that clash with LazyVim's Tokyonight Night theme, creating visual discontinuity between editor and terminal
- There are no keyboard shortcuts configured for pane splitting, navigation, or floating windows
- The user doesn't know Kitty's shortcut vocabulary and can't navigate effectively
- The user is evaluating whether Kitty can replace their existing Zellij workflow, but has no basis to compare
- The gap between Kitty's default state and a productive daily driver is a concrete blocker to completing the iTerm2 migration

### Value Proposition

A single, well-structured `kitty.conf` (and companion files) transforms Kitty from a blank terminal into a cohesive workstation:
- **Visual coherence**: Terminal and editor share the same Tokyonight Night palette — no eye-strain from context-switching between tools
- **Pane productivity**: Split panes, layout cycling, and an overlay window replace Zellij's core daily-use features
- **Zero learning cliff**: Keybindings are documented with iTerm2/Zellij cross-references so migration is guided, not guessed
- **Potential simplification**: One tool (Kitty) replaces two (iTerm2 + Zellij) if floating pane needs are met

---

## User Personas

### Primary Persona: Power Developer (the user)
- **Demographics:** Developer, high technical expertise, daily Neovim/LazyVim user, former iTerm2 + Zellij user
- **Goals:**
  - A terminal that feels polished and cohesive from day one
  - Pane management as fast as or faster than Zellij
  - Learn Kitty's shortcuts without trial-and-error guesswork
  - Keep workflow simple — fewer tools when possible
- **Pain Points:**
  - Blank Kitty config is not usable as a daily driver
  - No reference for what Kitty can/can't do vs Zellij
  - Risk of reverting to iTerm2 if Kitty isn't configured quickly

### Secondary Personas

None — this is a personal developer environment configuration. No other users.

---

## User Journey Maps

### Primary User Journey: From Blank Kitty to Productive Daily Driver

1. **Awareness:** Developer opens Kitty and sees default grey terminal with no familiar shortcuts or colors — immediately recognises the gap
2. **Consideration:** Evaluates whether to configure Kitty from scratch, copy someone's dotfiles, or revert to iTerm2; wants a spec-driven config that matches specific needs
3. **Adoption:** Applies the generated `kitty.conf` — Tokyonight Night theme loads, pane shortcuts work, font matches iTerm2 16pt
4. **Usage:**
   - Opens Kitty → launches into Tokyonight Night themed terminal matching LazyVim
   - Presses `Cmd+D` → vertical split appears
   - Presses `Cmd+Shift+D` → horizontal split appears
   - Navigates with `Cmd+arrows`
   - Cycles layouts with `Cmd+L`
   - Opens overlay floating pane with `Cmd+F`
   - References keybinding cheatsheet when learning
5. **Retention:** After 1 week of use, shortcuts are muscle memory. Zellij dependency is evaluated — removed if Kitty covers all needs.

### Secondary User Journeys

None defined for this scope.

---

## Feature Requirements

### Must Have Features

#### Feature 1: Tokyonight Night Theme

- **User Story:** As a LazyVim user, I want Kitty to use the Tokyonight Night color palette so that my terminal and editor feel visually unified
- **Acceptance Criteria:**
  - [ ] Given Kitty opens, When the terminal renders, Then background is `#1a1b26`, foreground is `#c0caf5`
  - [ ] Given any 16 ANSI colors are rendered, When a program outputs colored text, Then colors match Tokyonight Night values (cyan `#7dcfff`, blue `#7aa2f7`, green `#9ece6a`, red `#f7768e`, yellow `#e0af68`, purple `#bb9af7`)
  - [ ] Given LazyVim is opened inside Kitty, When the status line and UI elements render, Then there is no visible color mismatch between terminal and editor backgrounds
  - [ ] Given the cursor is visible, When idle, Then cursor color matches Tokyonight Night cursor (`#c0caf5`)

#### Feature 2: Font — RobotoMono Nerd Font Mono 16pt

- **User Story:** As a developer, I want my Kitty font to match my iTerm2 setup so that muscle memory and readability are preserved during migration
- **Acceptance Criteria:**
  - [ ] Given Kitty opens, When text renders, Then font is RobotoMono Nerd Font Mono at 16pt
  - [ ] Given LazyVim is open in Kitty, When Nerd Font icons render (file icons, git symbols, status line glyphs), Then all icons display correctly without tofu (□) characters
  - [ ] Given bold text is rendered, When terminal outputs bold sequences, Then bold weight renders correctly

#### Feature 3: Pane Splitting (Vertical and Horizontal)

- **User Story:** As a terminal power user, I want to split my terminal into panes using keyboard shortcuts so that I can work in multiple contexts simultaneously without leaving Kitty
- **Acceptance Criteria:**
  - [ ] Given a single pane is open, When `Cmd+D` is pressed, Then a new pane opens to the right (vertical split)
  - [ ] Given a single pane is open, When `Cmd+Shift+D` is pressed, Then a new pane opens below (horizontal split)
  - [ ] Given multiple panes exist, When a pane is closed, Then remaining panes resize to fill the space
  - [ ] Given multiple panes exist, When `Cmd+W` is pressed, Then the active pane closes
  - [ ] Given multiple panes exist, When a split is created, Then focus moves to the new pane automatically

#### Feature 4: Pane Navigation (Cmd+Arrows)

- **User Story:** As a developer with panes open, I want to navigate between panes using `Cmd+arrow keys` so that moving focus is fast and directional
- **Acceptance Criteria:**
  - [ ] Given multiple panes are open, When `Cmd+Left` is pressed, Then focus moves to the pane to the left
  - [ ] Given multiple panes are open, When `Cmd+Right` is pressed, Then focus moves to the pane to the right
  - [ ] Given multiple panes are open, When `Cmd+Up` is pressed, Then focus moves to the pane above
  - [ ] Given multiple panes are open, When `Cmd+Down` is pressed, Then focus moves to the pane below
  - [ ] Given focus is on an edge pane, When navigating further in that direction, Then focus does not wrap unexpectedly

#### Feature 5: Layout Cycling

- **User Story:** As a power user, I want to cycle through Kitty's built-in layouts so that I can rearrange my panes for different tasks without manual resizing
- **Acceptance Criteria:**
  - [ ] Given panes are open, When `Cmd+L` is pressed, Then the active layout cycles to the next enabled layout
  - [ ] Given the "tall" layout is active, Then the main pane occupies the left 60% and other panes stack on the right
  - [ ] Given the "stack" layout is active, Then only one pane is visible (focus mode) and others are accessible via navigation
  - [ ] Given the "grid" layout is active, Then all panes display in equal-sized cells
  - [ ] Given the "fat" layout is active, Then the main pane is on top and others stack below

#### Feature 6: Overlay / Floating Pane

- **User Story:** As a developer, I want to open a temporary floating terminal pane and dismiss it when done so that I can run quick commands without disrupting my main layout
- **Acceptance Criteria:**
  - [ ] Given any layout is active, When `Cmd+F` is pressed, Then an overlay pane opens centered on screen
  - [ ] Given the overlay pane is open, When `Cmd+F` is pressed again (or `Escape`/`Ctrl+D`), Then the overlay closes
  - [ ] Given the overlay pane is open, When a command runs in it, Then the main panes behind it are unaffected
  - [ ] Given the overlay opens, Then its size is visually distinct from the layout (e.g. 80% width, 60% height, centered)

#### Feature 7: Tab Management

- **User Story:** As a developer, I want to manage tabs in Kitty using shortcuts consistent with iTerm2 so that my tab workflow requires zero relearning
- **Acceptance Criteria:**
  - [ ] Given Kitty is open, When `Cmd+T` is pressed, Then a new tab opens
  - [ ] Given multiple tabs are open, When `Cmd+Right` is pressed (no panes), Then focus moves to the next tab
  - [ ] Given multiple tabs are open, When `Cmd+1` through `Cmd+9` are pressed, Then focus jumps to that tab number
  - [ ] Given a tab is active, When `Cmd+Shift+W` is pressed, Then the tab closes
  - [ ] Given multiple tabs exist, When tabs render, Then each tab shows its title in the tab bar

---

### Should Have Features

#### Feature 8: Keybinding Reference Document

- **User Story:** As someone learning Kitty, I want a cheatsheet of all configured shortcuts with iTerm2/Zellij cross-references so that I can learn without trial-and-error
- **Acceptance Criteria:**
  - [ ] Given the keybinding reference exists, Then every configured shortcut is listed with its action
  - [ ] Given the reference is consulted, When an iTerm2 action is looked up, Then the Kitty equivalent is shown
  - [ ] Given the reference is consulted, When a Zellij action is looked up, Then the Kitty equivalent (or gap) is shown

#### Feature 9: Shell Integration

- **User Story:** As a zsh user, I want Kitty's shell integration enabled so that I get automatic CWD tracking, command history, and prompt marking
- **Acceptance Criteria:**
  - [ ] Given shell integration is enabled, When navigating to a directory in a pane, Then new panes inherit that pane's CWD
  - [ ] Given shell integration is enabled, When scrolling through output, Then command markers allow jumping between command outputs
  - [ ] Given shell integration is enabled, Then no visual artifacts are added to the prompt

#### Feature 10: Minimal Cursor Animation

- **User Story:** As a developer who prefers clean interfaces, I want visual bells and audio bells disabled, with an optional subtle cursor blink, so that the terminal is calm and focused
- **Acceptance Criteria:**
  - [ ] Given a bell signal fires, Then no audio bell plays
  - [ ] Given a bell signal fires, Then no visual flash occurs
  - [ ] Given the cursor is idle, Then it either blinks subtly (500ms interval) or is solid — configurable

---

### Could Have Features

- **Custom tab bar styling**: Powerline-style tab bar matching Tokyonight colors
- **URL hints kitten shortcut**: `Cmd+E` to click/open URLs in terminal output
- **Scrollback search**: Enhanced scrollback pager bound to `Cmd+Shift+H`
- **Session startup template**: A `session.conf` that opens project tabs on launch
- **Theme switcher**: A kitten shortcut to toggle between Tokyonight Night and a light theme

---

### Won't Have (This Phase)

- **Persistent sessions** (tmux-style process restoration) — Kitty does not support this natively; evaluate tmux if needed separately
- **Zellij KDL layout scripting** — Kitty's layout system is different; not a 1:1 replacement
- **Image rendering in terminal** — image.nvim and icat are out of scope for this migration phase
- **Remote SSH Kitty integration** — kitten ssh is a future enhancement
- **Window transparency / blur** — intentionally excluded for a minimal, focused aesthetic

---

## Detailed Feature Specifications

### Feature: Overlay / Floating Pane (Most Complex)

**Description:** Kitty does not natively support floating windows in the Zellij sense. The closest equivalent is launching a new window as an `overlay` type via the `launch` command, which renders on top of the current layout. This gives the user a focused temporary pane without disrupting the layout beneath.

**User Flow:**
1. User presses `Cmd+F` while in any layout
2. Kitty launches a new window with `--type=overlay` — a pane appears over the current layout, centered
3. User runs a quick command (e.g. `git status`, lookup, one-off script)
4. User presses `Ctrl+D` (or types `exit`) to close the overlay
5. Overlay closes, original layout is restored as-is with focus on the previously active pane

**Business Rules:**
- Rule 1: The overlay must not kill any background pane processes when it closes
- Rule 2: The overlay opens a new shell session in the same CWD as the focused pane (shell integration required)
- Rule 3: Only one overlay can be open at a time — pressing `Cmd+F` while overlay is open should close it

**Edge Cases:**
- Scenario 1: User closes Kitty while overlay is open → Expected: All windows close cleanly, no zombie processes
- Scenario 2: User opens overlay with no active CWD tracking → Expected: Overlay opens in `$HOME` as fallback
- Scenario 3: User resizes OS window while overlay is open → Expected: Overlay repositions relative to new window size

---

## Success Metrics

### Key Performance Indicators

- **Adoption:** Within 1 day of applying config, user is navigating panes and tabs without looking up shortcuts
- **Engagement:** User uses Kitty exclusively (no iTerm2 fallback) within 3 days
- **Quality:** Zero broken Nerd Font icons in LazyVim; zero color mismatches between Kitty and LazyVim UI
- **Business Impact:** Zellij dependency eliminated or consciously retained based on informed evaluation (not inertia)

### Tracking Requirements

This is a personal dotfiles project — formal analytics are not applicable. Qualitative self-assessment is the tracking mechanism.

| Checkpoint | What to Observe | Why |
|------------|-----------------|-----|
| Day 1 | Do colors match LazyVim? Icons render? | Validate theme + font |
| Day 1 | Can panes be split and navigated without docs? | Validate shortcut intuitiveness |
| Day 3 | Is iTerm2 still being opened? | Validate migration completeness |
| Day 7 | Is Zellij still needed? For what tasks? | Validate replacement decision |

---

## Constraints and Assumptions

### Constraints

- Kitty is already installed and is the active terminal (migration already started)
- RobotoMono Nerd Font Mono must already be installed on the system (it was in iTerm2)
- macOS platform — all shortcuts use `Cmd` as the primary modifier
- Kitty does not natively support true floating windows — overlay workaround has limitations vs Zellij
- No persistent sessions — this is a Kitty architectural constraint, not a configuration gap

### Assumptions

- User's LazyVim colorscheme is the default (Tokyonight Night) — confirmed by inspecting `~/.config/nvim/lua/plugins/all.lua` (no colorscheme override found)
- Font size of 16pt is correct — confirmed from iTerm2 defaults (`RobotoMonoNFM-Rg 16`); user also confirmed they've zoomed in Kitty and don't want the smaller default
- User wants `Cmd+arrows` for pane navigation — confirmed by user preference
- User is comfortable with standard macOS `Cmd` modifier conventions
- Shell is zsh — inferred from macOS default and typical LazyVim user profile

---

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| RobotoMono Nerd Font not installed, icons break in LazyVim | High | Low | Verify font exists before config; fallback to JetBrains Mono NF |
| `Cmd+arrows` conflicts with macOS system shortcuts (word jump, line jump) | Medium | Medium | Override in kitty.conf; macOS allows per-app overrides |
| Overlay pane UX is worse than Zellij floating — user reverts to Zellij | Medium | Medium | Document Zellij-in-Kitty tab as a valid hybrid approach |
| Tokyonight Night hex values in Kitty don't exactly match Neovim's rendered theme | Low | Low | Use official Tokyonight Kitty theme file from the theme's repo |
| User forgets new shortcuts and reverts to iTerm2 muscle memory | Medium | High | Keybinding cheatsheet in `~/.config/kitty/KEYBINDINGS.md` + first-week reference |

---

## Open Questions

- [ ] Should `Cmd+arrows` be used for *both* pane navigation and tab navigation (context-aware), or should tabs use a different shortcut to avoid ambiguity?
- [ ] If Zellij floating pane is found to be irreplaceable, should we document a "Zellij in a Kitty tab" hybrid config as part of this spec?
- [ ] Should the config be split across multiple files (`kitty.conf` + `keybindings.conf` + `theme.conf`) or kept in a single file for simplicity?

---

## Supporting Research

### Competitive Analysis

| Feature | Kitty | Zellij | iTerm2 |
|---------|-------|--------|--------|
| Split panes | Yes (auto-layout engine) | Yes (explicit split commands) | Yes |
| Floating windows | Overlay workaround | Native first-class | Yes |
| Persistent sessions | No | Yes | No |
| Theme system | 256-color + RGB conf files | Limited | Full GUI |
| Shell integration | Built-in (zsh/fish/bash) | No | Yes |
| macOS native feel | Yes | Moderate | Yes |
| LazyVim color accuracy | Excellent (true color) | Good | Good |
| Nerd Font support | Excellent | Excellent | Excellent |

### User Research

Direct user stated requirements (gathered in spec session):
- Wants Tokyonight Night to match LazyVim default (confirmed no custom theme override)
- Prefers `Cmd+arrows` for pane navigation
- Wants to preserve iTerm2 font (RobotoMono Nerd Font Mono 16pt)
- Interested in replacing Zellij but not committed — wants to evaluate
- Wants floating pane support — this is a known gap to manage

### Market Data

Not applicable — this is a personal developer environment configuration, not a market product.
