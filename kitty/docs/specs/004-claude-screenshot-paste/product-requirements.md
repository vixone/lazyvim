---
title: "Claude Screenshot Paste in Kitty Terminal"
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

- [x] Problem is validated by evidence (research findings, open GitHub issues)
- [x] Context → Problem → Solution flow makes sense
- [x] Every persona has at least one user journey
- [x] All MoSCoW categories addressed (Must/Should/Could/Won't)
- [x] No technical implementation details included
- [x] A new team member could understand this PRD

---

## Product Overview

### Vision

Enable developers using Claude Code CLI in Kitty terminal to share macOS screenshots with Claude in a single keypress — no manual file saving, no path typing.

### Problem Statement

macOS developers working with Claude Code CLI in Kitty terminal cannot easily share screenshots taken with `Ctrl+Cmd+Shift+4`. That shortcut copies the screenshot to clipboard only (no file is created), but Claude Code CLI requires either a file path or a working `Ctrl+V` clipboard paste. The native `Ctrl+V` approach has multiple open bugs causing silent failures on macOS (GitHub issues #1361, #2102, #12644, #29776). The result: developers must manually save the screenshot to disk, note the path, and type it — breaking their flow.

### Value Proposition

A single keyboard shortcut that automatically extracts the clipboard image, saves it to a timestamped temp file, and inserts the file path into the active terminal prompt. This closes the gap between macOS screenshot capture and Claude Code image input with zero friction and no dependency on the buggy native paste path.

---

## User Personas

### Primary Persona: Developer using Claude Code CLI in Kitty

- **Demographics:** Software developer, macOS user, technical power user with custom terminal setup
- **Goals:** Share visual context (UI bugs, error dialogs, layout questions, code screenshots) with Claude quickly without interrupting flow
- **Pain Points:**
  - `Ctrl+V` in Claude Code silently fails or is inconsistent on macOS
  - `Cmd+V` doesn't work at all (wrong shortcut for Claude Code)
  - `pbpaste` is image-incompatible
  - Manually saving screenshots to disk and typing paths is slow and disruptive
  - No feedback when paste fails — no error message, just nothing happens

---

## User Journey Maps

### Primary User Journey: Share a screenshot with Claude

1. **Trigger:** Developer notices a UI bug, error, or visual they want Claude to analyze
2. **Capture:** Presses `Ctrl+Cmd+Shift+4`, draws a region — screenshot goes to clipboard
3. **Current pain:** Tries `Ctrl+V` in Claude Code → silent failure; must alt-tab to Finder, save file, copy path, type it in
4. **With this feature:** Presses a single Kitty keybinding → file path auto-inserted into prompt → attaches screenshot and continues typing the question
5. **Retention:** Works reliably every time, no thought required — becomes muscle memory

### Secondary User Journey: Paste a full-screen screenshot

1. Developer uses `Ctrl+Cmd+Shift+3` (full screen to clipboard)
2. Presses same keybinding
3. Screenshot is extracted and path inserted, same as region capture

---

## Feature Requirements

### Must Have Features

#### Feature 1: Single-keypress clipboard image → file path insertion

- **User Story:** As a developer using Claude Code CLI in Kitty, I want to press one key combination to convert my clipboard screenshot into a file path inserted at my terminal cursor, so that I can attach the image to my Claude prompt without leaving the terminal.
- **Acceptance Criteria (Gherkin Format):**
  - [ ] Given the macOS clipboard contains a screenshot, When I press the designated paste-image keybinding, Then a PNG file is saved to `/tmp/` with a unique timestamped name
  - [ ] Given the file is saved successfully, When the keybinding fires, Then the file path is typed into the active Kitty window at the current cursor position
  - [ ] Given Claude Code CLI is waiting for input, When the path is inserted, Then I can complete my message and send it normally
  - [ ] Given the clipboard contains no image, When I press the keybinding, Then no file is created and no path is inserted (or a clear error message is shown)

#### Feature 2: Clipboard image detection and format support

- **User Story:** As a developer, I want the feature to handle any image format that Claude Code CLI accepts, so that I don't need to worry about format compatibility.
- **Acceptance Criteria (Gherkin Format):**
  - [ ] Given the clipboard contains a PNG screenshot (most common for macOS screenshots), When the keybinding fires, Then the image is extracted and saved as PNG
  - [ ] Given the clipboard contains a JPEG image, When the keybinding fires, Then the image is saved successfully
  - [ ] Given the resulting file is under 5MB (Claude API limit), When the path is provided to Claude Code, Then Claude accepts and processes the image

### Should Have Features

- **Temp file cleanup:** Old screenshot files in `/tmp/` older than 24 hours are automatically removed to avoid disk accumulation
- **Path format:** The inserted path should be a bare absolute path (e.g., `/tmp/screenshot_1709123456.png`) so it's directly usable in Claude Code without quoting

### Could Have Features

- **Visual confirmation:** A brief Kitty notification or bell indicating the screenshot was saved and path inserted
- **Custom save directory:** Configurable destination directory instead of hardcoded `/tmp/`
- **Filename prefix:** Configurable prefix for the saved files (e.g., `claude_` prefix)

### Won't Have (This Phase)

- Automatic submission of the message after path insertion — user should control when to send
- Integration with macOS screenshot tool to auto-capture on keybinding (two separate concerns)
- Cloud upload or URL-based sharing of screenshots
- Support for non-image clipboard content (text, files)
- Patch or fix for Claude Code's native `Ctrl+V` clipboard paste bug (upstream issue)

---

## Detailed Feature Specifications

### Feature: Clipboard Image → Temp File → Path Insertion

**Description:** When the user presses the designated keybinding in Kitty, the system extracts the image from the macOS clipboard, saves it to a temporary file with a unique name, and types the absolute file path into the current terminal window at the cursor position. The user can then complete their Claude prompt naturally.

**User Flow:**
1. User takes screenshot with `Ctrl+Cmd+Shift+4` → screenshot in clipboard
2. User presses designated paste-image keybinding in Kitty
3. System extracts image from clipboard and saves to `/tmp/screenshot_<timestamp>.png`
4. System types the file path into the terminal at the current cursor
5. User types their question/context around or after the path, then sends to Claude

**Business Rules:**
- Rule 1: File must be saved before the path is typed — if save fails, do not type anything
- Rule 2: Filename must include a timestamp or random suffix to avoid collisions between rapid consecutive uses
- Rule 3: The typed path must be the full absolute path (starting with `/tmp/`)
- Rule 4: No newline is appended after the path — user controls submission

**Edge Cases:**
- Clipboard has no image → Expected: silent no-op or brief notification; no broken path inserted
- Clipboard extraction tool not installed → Expected: clear error notification pointing to fix
- `/tmp/` is not writable → Expected: error notification; no path inserted
- File already exists at target path → Expected: timestamp ensures uniqueness; overwrite only if guaranteed unique

---

## Success Metrics

### Key Performance Indicators

- **Adoption:** Feature is used in place of manual file-save workflow 100% of the time for the primary user
- **Reliability:** Zero silent failures — if the image paste fails, the user is notified
- **Speed:** End-to-end from keybinding press to path-in-prompt takes under 1 second
- **Quality:** No stale temp files accumulate (< 20 files in `/tmp/` from this feature at any time)

### Tracking Requirements

This is a personal developer tool; formal analytics are not applicable. Success is validated by:

| Event | Properties | Purpose |
|-------|------------|---------|
| Keybinding pressed | Clipboard had image (yes/no) | Validate feature is being used |
| File saved | File size, format | Verify format compatibility |
| Path inserted | Success/failure | Validate end-to-end reliability |

---

## Constraints and Assumptions

### Constraints

- macOS only — this workflow relies on macOS clipboard behavior and `Ctrl+Cmd+Shift+4`
- Kitty terminal only — the keybinding mechanism is Kitty-specific
- Requires at least one image extraction tool to be available (`pngpaste` via Homebrew, `kitten clipboard`, or `osascript`)
- Claude Code CLI must be running in the Kitty window (not SSH remote sessions without clipboard forwarding)
- Image must be under 5MB for Claude API acceptance

### Assumptions

- User has Kitty terminal configured and running on macOS
- User has Homebrew available for installing `pngpaste` if needed
- `kitten clipboard` is available (bundled with Kitty)
- `/tmp/` directory is writable
- User is running Claude Code CLI interactively (not in a script)

---

## Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Clipboard extraction tool not installed | High — feature completely broken | Low — `kitten clipboard` is bundled with Kitty | Prefer `kitten clipboard` as primary tool; document `pngpaste` as fallback |
| `Ctrl+V` in Claude Code gets fixed upstream | Low — our solution becomes redundant | Low | Our approach is faster even if native paste works |
| Temp file accumulation fills disk | Low | Low — screenshots are small | Add cleanup step; document manual cleanup |
| Path with spaces/special chars causes issues | Medium — Claude Code might misparse | Low — `/tmp/` paths are clean | Use timestamp-only filenames without spaces |
| Clipboard contains non-image data when keybinding pressed | Low — confusing behavior | Medium — accidental press | Gracefully no-op with optional notification |

---

## Open Questions

- [x] Should the path be inserted as a bare path or wrapped in backticks/quotes? → **Bare path** (Claude Code handles it without quoting)
- [x] Should a newline be appended? → **No** — user controls when to submit
- [ ] Should multiple rapid screenshots create multiple files? → Assume yes (timestamp ensures uniqueness) — verify in implementation

---

## Supporting Research

### Competitive Analysis

- **Aider (terminal AI tool):** Supports `/add image.png` command but requires file path — same problem
- **VS Code terminal:** vscode-terminal-image-paste extension solves this exactly with `Cmd+Alt+V` → saves to `.cp-images/` and inserts path; validates our approach
- **tmux-paste-image:** tmux plugin that saves clipboard image and pastes path — same pattern, different terminal

### User Research

Validated by multiple open GitHub issues in `anthropics/claude-code`:
- Issue #1361: Can't paste image from clipboard
- Issue #2102: Clipboard image parsing failure on macOS Screenshot Utility
- Issue #12644: Screenshot support via clipboard paste in Claude Code CLI
- Issue #29776: Ctrl+V image paste fails silently

### Market Data

Personal developer tooling — not applicable. The pattern (clipboard → temp file → path insertion) is validated by VS Code extensions and tmux plugins that solve the identical problem in their respective environments.
