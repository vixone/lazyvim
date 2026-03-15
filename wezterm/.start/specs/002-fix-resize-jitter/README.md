# Specification: 002-fix-resize-jitter

## Status

| Field | Value |
|-------|-------|
| **Created** | 2026-03-15 |
| **Current Phase** | Initialization |
| **Last Updated** | 2026-03-15 |

## Documents

| Document | Status | Notes |
|----------|--------|-------|
| requirements.md | pending | |
| solution.md | pending | |
| plan/ | pending | |

**Status values**: `pending` | `in_progress` | `completed` | `skipped`

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-03-15 | Created spec 002 | Persistent resize jitter on main session needs root-cause analysis and definitive fix |

## Context

User reports persistent jittering/flickering in WezTerm when resizing windows. Multiple prior fix attempts (status caching, debounce, render loop breaks) have not fully resolved the issue. Need root-cause analysis and a permanent fix.

---
*This file is managed by the specify-meta skill.*
