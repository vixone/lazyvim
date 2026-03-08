---
title: "Stack Window Count in Tab Title"
status: complete
version: "1.0"
---

# Solution Design Document

## Validation Checklist

### CRITICAL GATES (Must Pass)

- [x] All required sections are complete
- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Architecture pattern is clearly stated with rationale
- [x] **All architecture decisions confirmed by user** (ADR-10 confirmed)
- [x] Every interface has specification

### QUALITY CHECKS (Should Pass)

- [x] All context sources are listed with relevance ratings
- [x] Project commands are discovered from actual project files
- [x] Constraints → Strategy → Design → Implementation path is logical
- [x] Every component in diagram has directory mapping
- [x] A developer could implement from this design

---

## Constraints

CON-1 **Config-only**: No new files. Change must land entirely in `kitty.conf` — two template lines.
CON-2 **Template variables only**: Use native kitty template variables (`num_windows`, `layout_name`). No external scripts or kittens.
CON-3 **Preserve existing format**: The folder-name-based title and session prefix must remain intact.
CON-4 **Conditional display**: Indicator appears ONLY when `layout_name == 'stack'` and `num_windows > 1`. Silent in all other layouts.

---

## Implementation Context

### Required Context Sources

```yaml
- file: ~/.config/kitty/kitty.conf
  relevance: HIGH
  why: "Lines 16-17 — the two template lines being modified"

- file: ~/.config/kitty/docs/specs/002-overlay-and-stacked-panes/solution-design.md
  relevance: MEDIUM
  why: "Established ADR numbering (ADR-6 through ADR-9) — this spec adds ADR-10"
```

### Implementation Boundaries

- **Must Preserve**: Current folder-name title format, session prefix in active tab
- **Can Modify**: `tab_title_template` and `active_tab_title_template` values in `kitty.conf`
- **Must Not Touch**: `tab_bar_style`, `tab_powerline_style`, `tab_bar_min_tabs`, all other config

### Project Commands

```bash
# Reload config (no restart needed)
Reload: Ctrl+Shift+F5  (inside Kitty)

# Verify no parse errors
Debug: kitty --debug-config
```

---

## Solution Strategy

- **Architecture Pattern**: Config-only patch — Python f-string template extension
- **Integration Approach**: Extend existing template strings with a conditional suffix using native kitty template variables
- **Justification**: `num_windows` and `layout_name` are natively available in kitty's tab title template context. A conditional expression appended to the existing template requires zero new files, zero new code, and no build steps.
- **Key Decision**: ADR-10 (indicator format)

---

## Building Block View

### Components

```
kitty.conf
  └── tab_title_template (line 16)          ← MODIFY: add conditional suffix
  └── active_tab_title_template (line 17)   ← MODIFY: add conditional suffix
```

### Directory Map

```
~/.config/kitty/
├── kitty.conf       # MODIFY: lines 16-17 only
└── (no new files)
```

### Interface Specifications

#### Template Variables Used

| Variable | Type | Value in stack | Value elsewhere |
|----------|------|----------------|-----------------|
| `layout_name` | string | `'stack'` | `'tall'`, `'fat'`, `'grid'` |
| `num_windows` | int | count of windows in tab | same (irrelevant outside stack) |
| `session_name` | string | session name or `''` | same |
| `tab.active_wd` | object | current working dir object | same |

#### Template Before / After

**Before:**
```python
tab_title_template       "{tab.active_wd.rsplit('/', 1)[-1]}"
active_tab_title_template "{(session_name + ' › ') if session_name else ''}{tab.active_wd.rsplit('/', 1)[-1]}"
```

**After (ADR-10 applied):**
```python
tab_title_template       "{tab.active_wd.rsplit('/', 1)[-1]}{(' ⊞' + str(num_windows)) if layout_name == 'stack' and num_windows > 1 else ''}"
active_tab_title_template "{(session_name + ' › ') if session_name else ''}{tab.active_wd.rsplit('/', 1)[-1]}{(' ⊞' + str(num_windows)) if layout_name == 'stack' and num_windows > 1 else ''}"
```

### Implementation Examples

#### Template Logic Walkthrough

| Scenario | `layout_name` | `num_windows` | Rendered title (active, no session) |
|----------|---------------|---------------|--------------------------------------|
| 3 panes, stack layout | `'stack'` | `3` | `proj ⊞3` |
| 1 pane, stack layout | `'stack'` | `1` | `proj` (no indicator — only 1 window, nothing hidden) |
| 3 panes, tall layout | `'tall'` | `3` | `proj` (no indicator — all panes visible) |
| Session + 2 panes, stack | `'stack'` | `2` | `work › proj ⊞2` |
| Session + 1 pane, tall | `'tall'` | `1` | `work › proj` |

---

## Runtime View

### Primary Flow

1. User creates 3 panes with `Cmd+D` → tab title shows `proj` (tall layout, no indicator)
2. User presses `Cmd+Shift+F` → layout switches to stack → tab title immediately updates to `proj ⊞3`
3. User presses `Opt+0` to cycle to next pane → title stays `proj ⊞3` (count reflects total, not position)
4. User presses `Cmd+Shift+F` again → returns to previous layout → indicator disappears

### Error Handling

- **`num_windows == 1` in stack**: Condition `num_windows > 1` suppresses indicator. Clean — no `⊞1` noise.
- **Template syntax error**: `kitty --debug-config` will surface parse errors. Config reload (`Ctrl+Shift+F5`) shows error dialog.
- **Unicode rendering**: `⊞` (U+229E) renders in all Nerd Font variants. Fallback: replace with `#` if rendering issues observed.

---

## Deployment View

Config-only change. No build, no install, no restart.

- **Apply**: Edit `kitty.conf` lines 16-17
- **Reload**: `Ctrl+Shift+F5` inside Kitty (hot-reload, no process restart)
- **Rollback**: Revert the two template lines to original values, reload

---

## Cross-Cutting Concepts

### User Interface & UX

```
Tab bar — stack layout active, 3 windows:
┌─────────────────────────────────────────┐
│  ● proj ⊞3  ○ other-tab                │
└─────────────────────────────────────────┘

Tab bar — tall layout, same 3 windows:
┌─────────────────────────────────────────┐
│  ● proj     ○ other-tab                │
└─────────────────────────────────────────┘
```

The `⊞` symbol (squared plus / "stacked windows" semantic) is distinct from existing tab content and visually suggests "stacked layers."

---

## Architecture Decisions

- [ ] **ADR-10: Stack indicator format** — `⊞N` suffix on tab title
  - **Choice**: Append `⊞N` (e.g., `⊞3`) only when `layout_name == 'stack' and num_windows > 1`
  - **Rationale**: `⊞` is semantically fitting (stacked squares), visually compact, doesn't conflict with the `›` session separator already in use. Conditional on `> 1` avoids pointless `⊞1` when nothing is actually hidden.
  - **Alternatives considered**:
    - `(N)` — too generic, could be confused with other tab info
    - `[N]` — bracket syntax conflicts with some powerline themes
    - Always-on (even outside stack) — adds noise in tall/grid layouts where all panes are already visible
    - Show `N/M` (current/total) — requires knowing active window index, not available in template context without custom `tab_bar.py`
  - **Trade-offs**: Shows total count, not position (e.g., `⊞3` not `2/3`). To know position, user still uses `Opt+9`/`Opt+0` or `Cmd+;`. This is acceptable — the count alone answers "how many are hidden."
  - User confirmed: ✅ 2026-03-06

---

## Quality Requirements

- **Immediacy**: Tab title updates within one repaint cycle after layout switch (kitty redraws tab bar on layout change)
- **Zero regression**: All non-stack tab titles render identically to current behavior
- **No flicker**: Condition is pure Python f-string — no I/O, no subprocess, evaluates inline

---

## Acceptance Criteria

**Stack visibility:**
- [ ] WHEN layout is `stack` AND tab has 2+ windows, THE SYSTEM SHALL append ` ⊞N` to the tab title (both active and inactive)
- [ ] WHEN layout is `stack` AND tab has exactly 1 window, THE SYSTEM SHALL NOT show the stack indicator
- [ ] WHILE layout is NOT `stack`, THE SYSTEM SHALL render tab titles without stack indicator

**Regression:**
- [ ] THE SYSTEM SHALL preserve `session › folder` format in active tab when session is set
- [ ] THE SYSTEM SHALL preserve `folder` format in inactive tabs (no session prefix)

---

## Risks and Technical Debt

### Implementation Gotchas

- `num_windows` counts ALL windows in the tab, including the currently-visible one. So `⊞3` means 3 total (1 visible + 2 hidden). This is correct — it answers "how many are in the stack."
- Template expressions use Python f-string syntax. `str(num_windows)` is needed because `num_windows` is an int and string concatenation requires explicit cast.
- `layout_name` reflects the active layout of the tab, not the OS window. If you have tabs in different layouts, each tab's indicator is independent — correct behavior.

---

## Glossary

| Term | Definition |
|------|------------|
| `stack` layout | Kitty layout where only one window is visible at a time; others are hidden behind it |
| `num_windows` | Kitty template variable: integer count of all windows in the current tab |
| `layout_name` | Kitty template variable: string name of the active layout (e.g., `'stack'`, `'tall'`) |
| `⊞` | Unicode U+229E "Squared Plus" — used as the stack indicator symbol |
| tab title template | Python f-string evaluated by kitty to render each tab's label in the tab bar |
