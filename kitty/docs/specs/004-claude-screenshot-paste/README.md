# Specification: 004-claude-screenshot-paste

## Status

| Field | Value |
|-------|-------|
| **Created** | 2026-03-06 |
| **Current Phase** | Complete |
| **Last Updated** | 2026-03-06 |

## Documents

| Document | Status | Notes |
|----------|--------|-------|
| product-requirements.md | completed | |
| solution-design.md | completed | ADR-1: kitten clipboard, ADR-2: paste_screenshot.sh, ADR-3: cmd+shift+v |
| implementation-plan.md | completed | 2 phases, 6 tasks, sequential (T1.1→T1.2→T2.x) |

**Status values**: `pending` | `in_progress` | `completed` | `skipped`

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-03-06 | Spec created | User wants to paste macOS screenshots (Ctrl+Cmd+Shift+4) directly into Claude CLI in Kitty terminal |

## Context

Enable pasting clipboard screenshots captured via macOS shortcut (Ctrl+Cmd+Shift+4) directly into Claude Code running inside Kitty terminal. This allows attaching images to Claude conversations without saving to disk first.

---
*This file is managed by the specify-meta skill.*
