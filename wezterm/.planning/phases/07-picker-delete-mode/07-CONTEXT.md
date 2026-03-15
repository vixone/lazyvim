# Phase 7: Picker Delete Mode - Context

**Gathered:** 2026-03-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Delete sessions directly from the fuzzy picker without dropping to CLI. Users toggle into a delete mode, select a session, confirm deletion via typed prompt, and return to the normal picker. This extends the existing picker (`picker.lua`) and uses the existing `manager.delete_session()` API.

</domain>

<decisions>
## Implementation Decisions

### Delete mode indicator
- Title changes from "Sessions" to "Sessions [DELETE]"
- Deletable sessions get a "🗑 " (trash emoji) prefix
- Current session shown WITHOUT trash icon — labeled with "(current)" instead of `*` prefix
- "+" Create new session sentinel is hidden in delete mode
- Selecting the current session in delete mode is a silent no-op

### Confirmation style
- Use WezTerm's `PromptInputLine` asking "Delete '<session-name>'? Type 'yes' to confirm:"
- Accept "y" or "yes" (case-insensitive) as confirmation
- Anything else (including empty input or Escape) cancels silently — no toast, no message
- No success toast after deletion — the session disappearing from the list is feedback enough

### Post-deletion flow
- After confirmed deletion: picker reopens in **switch mode** with updated session list
- After cancelled deletion: picker reopens in **delete mode** (user probably still wants to delete something)
- Auto-close picker if no deletable sessions remain after a deletion (only current session left)
- Escape behavior in delete mode: Claude's discretion (close entirely vs. back to switch mode — depends on what InputSelector supports)

### Mode toggle mechanism
- Claude's discretion: research whether Tab key can be captured in InputSelector
- If Tab works: use Tab to toggle between switch and delete modes
- If Tab doesn't work: fall back to sentinel item approach ("🗑 Delete mode..." at bottom of switch mode, "← Back to sessions..." at bottom of delete mode)
- Either way, the visual UX must match the mockups above

### Claude's Discretion
- Mode toggle implementation (Tab capture vs. sentinel items)
- Escape behavior in delete mode (close entirely vs. back to switch mode)
- Whether to reuse the same `show_picker` function with a mode parameter or create a separate `show_delete_picker` function
- Error handling for failed deletions (toast pattern already established)

</decisions>

<specifics>
## Specific Ideas

- Emoji prefix (🗑) makes delete mode visually unmistakable — can't accidentally confuse it with switch mode
- PromptInputLine for confirmation matches the existing create-new pattern — consistent interaction model
- Returning to switch mode after delete is intentional: the common flow is "clean up one stale session, then switch to what I actually want"
- "(current)" label in delete mode is more descriptive than `*` — makes it clear WHY you can't delete it

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `picker.lua`: Existing picker with `InputSelector`, `action_callback`, sentinel IDs (`__empty__`, `__create__`) — extend this for delete mode
- `manager.delete_session(name)`: Full delete logic already exists — protects "default" workspace, switches away from active session before deleting, removes JSON + closes panes
- `PromptInputLine`: Already used for create-new session — same pattern for delete confirmation
- `toast_notification`: Already used for error feedback in picker callback

### Established Patterns
- Sentinel IDs for special items (`__empty__`, `__create__`) — can add `__delete_mode__` and `__back__` sentinels
- `wezterm.action_callback` wrapping `InputSelector` for custom logic
- `manager.list_sessions()` returns `{name, active, last_saved}` — filter for delete mode display
- `wezterm.mux.get_active_workspace()` for current session detection

### Integration Points
- `picker.lua` — primary file to modify, add delete mode logic
- `manager.delete_session(name)` — called from picker's delete confirmation callback
- `config.keys` in wezterm.lua — no changes needed (same CMD+CTRL+S keybinding)

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 07-picker-delete-mode*
*Context gathered: 2026-03-14*
