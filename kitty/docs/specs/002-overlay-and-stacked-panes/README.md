# Specification: 002-overlay-and-stacked-panes

## Status

| Field | Value |
|-------|-------|
| **Created** | 2026-03-06 |
| **Current Phase** | Ready |
| **Last Updated** | 2026-03-06 |

## Documents

| Document | Status | Notes |
|----------|--------|-------|
| product-requirements.md | completed | Toggle overlay, stack navigation, visual picker |
| solution-design.md | completed | ADR-6 (quick_access_terminal), ADR-7 (opt+hjkl), ADR-8 (cmd+;), ADR-9 (opt+9/0) |
| implementation-plan.md | completed | 3 phases, 10 tasks, 4 files, Opt+9/0 stack cycle |

**Status values**: `pending` | `in_progress` | `completed` | `skipped`

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-03-06 | Started spec | User wants Zellij-style overlay toggle + stacked panes navigation |
| 2026-03-06 | Scratchpad position: top (Quake style) | User prefers drop-down from top over centered float |
| 2026-03-06 | Using kitten quick_access_terminal | Built-in Kitty v0.42.0+ kitten solves toggle+transparency natively — no scripting needed |

## Context

Enhancing the existing Kitty config (spec 001) with:
- Zellij-like overlay: toggleable floating pane (open/close with same key), persistent across toggle, centered
- Stacked panes: multiple panes in stack layout with easy keyboard navigation between them
- Builds on top of: kitty.conf, theme.conf, keybindings.conf from spec 001

---
*This file is managed by the specify-meta skill.*
