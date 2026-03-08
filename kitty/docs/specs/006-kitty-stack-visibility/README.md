# Specification: 006-kitty-stack-visibility

## Status

| Field | Value |
|-------|-------|
| **Created** | 2026-03-06 |
| **Current Phase** | Ready |
| **Last Updated** | 2026-03-06 |

## Documents

| Document | Status | Notes |
|----------|--------|-------|
| product-requirements.md | skipped | Requirements obvious from description — went straight to SDD |
| solution-design.md | completed | ADR-10 (⊞N suffix), template variables num_windows + layout_name |
| implementation-plan.md | completed | 2 phases, 4 tasks, 1 file (kitty.conf lines 16-17) |

**Status values**: `pending` | `in_progress` | `completed` | `skipped`

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-03-06 | Started spec | User wants Zellij-style stack visibility — see all pane titles/count when in stack layout |
| 2026-03-06 | Scope: tab title count only | Show ⊞N in tab bar when in stack layout — minimal, no new files, instant feedback |
| 2026-03-06 | Skipped PRD | Feature is narrow and requirements obvious — went straight to SDD+PLAN |
| 2026-03-06 | ADR-10 confirmed | ⊞N format: (' ⊞' + str(num_windows)) if layout_name == 'stack' and num_windows > 1 |

## Context

When kitty's stack layout is active, only one pane content is visible — there's no visual indicator of how many other panes exist in the stack. Zellij shows all pane title bars stacked vertically so you always know what's in the stack. This spec explores how to replicate that visibility in kitty.

Builds on:
- spec 001: base kitty config
- spec 002: stack layout (Cmd+Shift+F), Opt+9/0 cycle, Cmd+; picker

---
*This file is managed by the specify-meta skill.*
