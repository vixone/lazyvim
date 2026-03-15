---
created: "2026-03-14T21:21:26.852Z"
title: Add delete mode to session picker
area: ui
files:
  - lua/session/picker.lua
  - lua/session/manager.lua:153-216
---

## Problem

The fuzzy session picker (CMD+CTRL+S) currently supports switching and creating sessions, but has no way to delete sessions. Users must drop to CLI (`wez-session delete <name>`) to remove sessions. A delete mode within the picker would make it a one-stop shop for all session operations.

## Solution

User suggestion: Tab key toggles delete mode in the picker. Possible approaches:

- **Tab toggle:** Normal mode shows sessions for switching, Tab switches to delete mode where selecting a session deletes it (with confirmation). Visual indicator (e.g., red title "Delete Session" or prefix change) to make mode obvious.
- **Sentinel entry:** Add `- Delete session...` sentinel (like `+ Create new session...`), which opens a second InputSelector showing sessions in delete context.
- **Long-press or modifier:** Hold Shift while selecting to delete instead of switch.

`manager.delete_session(name)` already exists and handles JSON cleanup + pane closing. The picker just needs a UI path to invoke it with a confirmation step.
