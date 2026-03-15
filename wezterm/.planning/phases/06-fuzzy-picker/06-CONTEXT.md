# Phase 6: Fuzzy Picker - Context

**Gathered:** 2026-03-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Keyboard-triggered fuzzy search overlay for instant session switching. Users press a keybinding, see a searchable list of all sessions, and select one to switch to (or restore from JSON). This uses WezTerm's built-in `InputSelector` action. Creating sessions from the picker is included (type a new name). Phase 7 (on-launch picker) is separate.

</domain>

<decisions>
## Implementation Decisions

### Picker appearance
- Title: "Sessions" — simple and direct
- Rows show session name only — no status, no timestamps, no metadata
- No description/subtitle line below the title
- Use Catppuccin theme defaults — no custom color overrides, let InputSelector inherit theme

### Session indicators
- Current session marked with `*` prefix (same as CLI `wez-session list` — git branch style)
- No visual distinction between active and saved-only sessions — attach handles the difference transparently
- Current session included in the list (not hidden) — selecting it is a silent no-op
- Sort order: most recently saved first (matches `list_sessions()` default)

### Selection behavior
- Instant switch on selection — no confirmation dialog. Debounce internally to prevent Pitfall #5 (rapid selection causing tab switching frenzy)
- Selecting current session (* prefixed): silent no-op — just close the picker
- Empty list: show the empty picker — user sees there's nothing to switch to and dismisses
- Rely on existing auto-save (update-status throttled at 2 seconds) — no explicit save before picker opens
- Selection calls `manager.attach_session(name)` — smart behavior: switch if running, restore from JSON if saved-only

### Keybinding & dismiss
- Open picker: CMD+CTRL+S (separate modifier combo from the CMD+SHIFT group used for other features)
- Dismiss: Escape only (InputSelector native behavior) — no toggle with same keybinding
- Always available even without mux daemon connection — saved JSON sessions still work
- Create-if-not-found: if user types a name that doesn't match any existing session and confirms, create a new session with that name and switch to it (uses `manager.create_session(name)`)

### Claude's Discretion
- InputSelector configuration details (alphabet, fuzzy matching settings)
- How to implement create-if-not-found within InputSelector's callback model
- Debounce strategy for rapid selection prevention
- Error handling for failed attach/create operations
- Whether to add the picker as a new Lua module (e.g., `lua/session/picker.lua`) or inline in wezterm.lua

</decisions>

<specifics>
## Specific Ideas

- Picker should feel instantaneous — CMD+CTRL+S and the list is there
- Name-only rows keep it scannable — you don't need metadata to know which session you want
- `*` prefix is universally recognized (git branch convention) — consistency with CLI output
- Create-if-not-found makes the picker a one-stop shop: switch OR create, no need to drop to CLI for common operations

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lua/session/manager.lua`: `list_sessions()` returns `{name, active, last_saved}` sorted by most recent — picker data source
- `lua/session/manager.lua`: `attach_session(name)` — smart switch-or-restore, handles all switching logic
- `lua/session/manager.lua`: `create_session(name)` — idempotent create with validation (alphanumeric + dashes + underscores)
- `wezterm.action_callback` — pattern used throughout for custom keybinding actions (tab lock, theme toggle, etc.)
- `wezterm.mux.get_active_workspace()` — for detecting current session to mark with `*`

### Established Patterns
- Keybinding block in `config.keys` array with `{key, mods, action}` structure
- `wezterm.action_callback(function(window, pane) ... end)` for custom logic
- `act.InputSelector` for fuzzy selection UI (not yet used but documented in WezTerm API)
- Module pattern: `local M = {}` with functions, `return M`
- `pcall(require, ...)` for graceful module loading

### Integration Points
- `config.keys` in wezterm.lua — add new keybinding entry for CMD+CTRL+S
- `manager.lua` — all session operations already available, picker just needs to call them
- `wezterm.mux.get_active_workspace()` — for `*` prefix on current session
- `act.InputSelector` — WezTerm's built-in fuzzy selection action

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 06-fuzzy-picker*
*Context gathered: 2026-03-14*
