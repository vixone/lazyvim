# Kitty Keybindings Reference

> Migration guide for iTerm2 and Zellij users.

## Pane (Window) Management

| Action | Kitty | iTerm2 equiv | Zellij equiv |
|--------|-------|--------------|--------------|
| Split right (vsplit) | `Cmd+D` | `Cmd+D` | `Ctrl+P r` |
| Split below (hsplit) | `Cmd+Shift+D` | `Cmd+Shift+D` | `Ctrl+P d` |
| Close pane | `Cmd+W` | `Cmd+W` | `Ctrl+P x` |
| Navigate left | `Cmd+Left` or `Opt+H` | `Cmd+Opt+Left` | `Ctrl+P ←` |
| Navigate right | `Cmd+Right` or `Opt+L` | `Cmd+Opt+Right` | `Ctrl+P →` |
| Navigate up | `Cmd+Up` or `Opt+K` | `Cmd+Opt+Up` | `Ctrl+P ↑` |
| Navigate down | `Cmd+Down` or `Opt+J` | `Cmd+Opt+Down` | `Ctrl+P ↓` |

> **Note** *(ADR-3 — context-aware navigation)*: Arrow keys and `Opt+HJKL` navigate panes when neighbors exist; silent no-op otherwise.
> **Note** *(ADR-7 — vim spatial nav)*: `Opt+H/J/K/L` are aliases for `Cmd+arrows`. Both work identically. In stack layout, all spatial keys no-op — use `Opt+9/0` to cycle instead.

## Stack Layout Navigation

When in stack layout (`Cmd+Shift+F`), only one pane is visible at a time. Use these to navigate:

| Action | Kitty | Zellij equiv |
|--------|-------|--------------|
| Next pane (cycle forward) | `Opt+0` | `Ctrl+P →` |
| Previous pane (cycle back) | `Opt+9` | `Ctrl+P ←` |
| Jump to pane by number | `Cmd+;` | _(no direct equiv)_ |

> **Note** *(ADR-9 — split-keyboard friendly)*: `Opt+9/0` used instead of brackets — accessible on base layer without layers.

## Visual Pane Picker

| Action | Kitty |
|--------|-------|
| Show pane picker | `Cmd+;` |

Press `Cmd+;` to show numbered overlays on every pane — press the number to jump directly. Works in all layouts. Press `Escape` to cancel.

## Tab Management

| Action | Kitty | iTerm2 equiv |
|--------|-------|--------------|
| New tab | `Cmd+T` | `Cmd+T` |
| Close tab | `Cmd+Shift+W` | `Cmd+W` |
| Next tab | `Cmd+Shift+]` | `Cmd+Shift+]` |
| Previous tab | `Cmd+Shift+[` | `Cmd+Shift+[` |
| Jump to tab 1-9 | `Cmd+1` through `Cmd+9` | `Cmd+1` through `Cmd+9` |

## Layouts

| Action | Kitty |
|--------|-------|
| Cycle layout | `Cmd+L` |
| Toggle zoom (stack) | `Cmd+Shift+F` |

**Layout cycle order**: `tall` → `fat` → `grid` → `stack` → (repeat)

| Layout | Description |
|--------|-------------|
| `tall` | Main pane left (60%), others stack right — best for editor + aux |
| `fat` | Main pane top, others stack below — wide monitor with logs |
| `grid` | All panes equal size — comparing multiple outputs |
| `stack` | Single pane visible (focus mode) — distraction-free |

## Scratchpad (Quick-Access Terminal)

Replaces the old plain overlay. Frosted semi-transparent terminal that drops from the top.

| Action | Kitty | Zellij equiv |
|--------|-------|--------------|
| Toggle scratchpad (show/hide) | `Cmd+F` | `Alt+F` (`ToggleFloatingPanes`) |
| Close scratchpad (destroy session) | `Ctrl+D` / `exit` | `Ctrl+D` |
| Zoom current pane | `Cmd+Shift+F` | `Ctrl+P f` (fullscreen) |

> **Note** *(ADR-6)*: `Cmd+F` is a **toggle** — same key shows and hides. Session is **preserved** when hidden. Only destroyed on explicit `Ctrl+D` / `exit`.
> The scratchpad has a frosted/semi-transparent background (`opacity 0.85`) making it visually distinct from regular panes.

## OS Windows & Misc

| Action | Kitty | iTerm2 equiv |
|--------|-------|--------------|
| New OS window | `Cmd+N` | `Cmd+N` |
| Open scrollback | `Cmd+Shift+H` | `Cmd+Shift+B` |
| Open URL hints | `Cmd+E` | _(no equiv)_ |

## Quick Reload

| Action | How |
|--------|-----|
| Reload config | `Ctrl+Shift+F5` |
| Debug config | `kitty --debug-config` in shell |
