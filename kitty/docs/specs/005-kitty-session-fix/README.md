# Specification: 005-kitty-session-fix

## Status

| Field | Value |
|-------|-------|
| **Created** | 2026-03-06 |
| **Current Phase** | Ready |
| **Last Updated** | 2026-03-06 |

## Documents

| Document | Status | Notes |
|----------|--------|-------|
| product-requirements.md | completed | 5 Must-Have features, 8 bugs catalogued |
| solution-design.md | completed | 5 ADRs confirmed, all API syntax verified |
| implementation-plan.md | completed | 4 phases, 15 tasks, 6 parallel opportunities |

**Status values**: `pending` | `in_progress` | `completed` | `skipped`

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-03-06 | New spec (not amending 003) | Session loading is broken; root cause is `session_name` being written to session files by which_key.py but not recognized by kitty's session parser. Scope also includes UX improvements to the menu. |
| 2026-03-06 | Full redesign (not bug-fix only) | User wants to rethink the session feature from scratch — explore fzf, native kitty kittens, or other approaches beyond the current broken overlay. |
| 2026-03-06 | Full PRD → SDD → PLAN | Standard three-phase specification workflow. |

## Context

Session loading broken — `ValueError: Unknown command in session file: session_name`. The `_build_session()` function in `which_key.py` writes `session_name <name>` as the first line, but this is not a valid kitty session directive. Additionally the picker/saver UX needs a rethink.

---
*This file is managed by the specify-meta skill.*
