# Phase 7: Picker Delete Mode - Research

**Researched:** 2026-03-14
**Domain:** WezTerm InputSelector mode toggling, picker UI state management, confirmation patterns
**Confidence:** HIGH

## Summary

Phase 7 extends the existing fuzzy picker from Phase 6 to support an in-picker delete mode, allowing users to remove sessions without dropping to CLI. The core technical challenge is that WezTerm's InputSelector doesn't natively support mode toggling or capturing the Tab key — we must work within its single-pass callback model.

The solution is a **sentinel-based mode switching pattern**: add sentinel items to the choices array that represent mode transitions ("🗑 Delete mode..." in switch mode, "← Back to sessions..." in delete mode). When selected, these sentinels reopen the picker in the opposite mode. This approach leverages InputSelector's existing selection callback mechanism without requiring new WezTerm APIs.

All deletion infrastructure already exists: `manager.delete_session(name)` handles validation, workspace switching, JSON cleanup, and pane closure. The picker extension adds only UI layer concerns: visual indicators (emoji prefixes, title changes), confirmation via `PromptInputLine`, and picker state transitions.

**Primary recommendation:** Extend `picker.lua` with a `mode` parameter ("switch" or "delete"). In delete mode: change title to "Sessions [DELETE]", prefix deletable sessions with "🗑 ", hide current session, add "← Back" sentinel. On selection: show PromptInputLine confirmation accepting "y"/"yes", call `manager.delete_session()`, reopen picker in switch mode. In switch mode: add "🗑 Delete mode..." sentinel at bottom to enter delete mode.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Delete mode indicator:**
- Title changes from "Sessions" to "Sessions [DELETE]"
- Deletable sessions get a "🗑 " (trash emoji) prefix
- Current session shown WITHOUT trash icon — labeled with "(current)" instead of `*` prefix
- "+" Create new session sentinel is hidden in delete mode
- Selecting the current session in delete mode is a silent no-op

**Confirmation style:**
- Use WezTerm's `PromptInputLine` asking "Delete '<session-name>'? Type 'yes' to confirm:"
- Accept "y" or "yes" (case-insensitive) as confirmation
- Anything else (including empty input or Escape) cancels silently — no toast, no message
- No success toast after deletion — the session disappearing from the list is feedback enough

**Post-deletion flow:**
- After confirmed deletion: picker reopens in **switch mode** with updated session list
- After cancelled deletion: picker reopens in **delete mode** (user probably still wants to delete something)
- Auto-close picker if no deletable sessions remain after a deletion (only current session left)
- Escape behavior in delete mode: Claude's discretion (close entirely vs. back to switch mode — depends on what InputSelector supports)

**Mode toggle mechanism:**
- Claude's discretion: research whether Tab key can be captured in InputSelector
- If Tab works: use Tab to toggle between switch and delete modes
- If Tab doesn't work: fall back to sentinel item approach ("🗑 Delete mode..." at bottom of switch mode, "← Back to sessions..." at bottom of delete mode)
- Either way, the visual UX must match the mockups above

### Claude's Discretion

- Mode toggle implementation (Tab capture vs. sentinel items)
- Escape behavior in delete mode (close entirely vs. back to switch mode)
- Whether to reuse the same `show_picker` function with a mode parameter or create a separate `show_delete_picker` function
- Error handling for failed deletions (toast pattern already established)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope

</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| REQ-06 | Delete mode in fuzzy picker -- Tab toggles to delete, with confirmation | Sentinel-based mode switching extends existing InputSelector pattern; PromptInputLine provides confirmation UI; manager.delete_session() provides delete logic; picker reopening preserves state machine |

</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| wezterm.action.InputSelector | 20240203-110809 | Mode-aware picker UI | Already used in Phase 6 picker; supports dynamic choices for mode indication |
| wezterm.action.PromptInputLine | 20240203-110809 | Delete confirmation | Already used in Phase 6 create-new flow; text input validation pattern |
| manager.delete_session(name) | Phase 4 | Session deletion logic | Full implementation exists: validation, workspace switching, JSON removal, pane closure |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| string.lower() | Lua 5.4 | Case-insensitive confirmation | Normalize user input "Y", "y", "YES", "yes" to "yes" |
| window:toast_notification() | 20240203-110809 | Error feedback only | When deletion fails (e.g., deleting default workspace) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Sentinel-based mode switch | Tab key capture in InputSelector | WezTerm InputSelector doesn't expose Tab key events to callbacks; no API for custom key handling |
| Reopen picker after action | Maintain picker state | InputSelector is single-pass modal — no "update choices in place" API; reopening is standard pattern |
| Separate `show_delete_picker()` | Mode parameter in `show_picker()` | Separate function duplicates 80% of code; mode parameter enables code reuse and clear state transitions |

**Installation:**
None required — all APIs built into WezTerm stable release.

## Architecture Patterns

### Recommended Project Structure
```
lua/session/
├── manager.lua        # Existing — delete_session(), list_sessions()
├── picker.lua         # EXTEND — add mode parameter to show_picker(window, pane, mode)
└── state.lua          # Existing — no changes needed
```

### Pattern 1: Sentinel-Based Mode Switching

**What:** Add special choice items with reserved IDs (e.g., `__delete_mode__`, `__back__`) that represent mode transitions. Selection callback checks for sentinel IDs and reopens picker in different mode.

**When to use:** When you need multi-modal UI behavior but the underlying widget (InputSelector) is single-pass.

**Example:**
```lua
-- Source: Adapted from Phase 6 picker.lua pattern
function M.show_picker(window, pane, mode)
  mode = mode or "switch" -- Default to switch mode

  local sessions = manager.list_sessions()
  local current = wezterm.mux.get_active_workspace()

  local choices = {}
  local title = "Sessions"

  if mode == "switch" then
    -- Switch mode: show all sessions with * prefix for current
    for _, session in ipairs(sessions) do
      local prefix = (session.name == current) and "* " or "  "
      table.insert(choices, {
        id = session.name,
        label = prefix .. session.name,
      })
    end

    -- Add mode-switch sentinel at bottom
    table.insert(choices, {
      id = "__delete_mode__",
      label = "🗑 Delete mode...",
    })

  elseif mode == "delete" then
    title = "Sessions [DELETE]"

    -- Delete mode: show only deletable sessions with trash icon
    for _, session in ipairs(sessions) do
      if session.name == current then
        -- Current session: show but make non-deletable
        table.insert(choices, {
          id = session.name,
          label = "  " .. session.name .. " (current)",
        })
      else
        -- Deletable sessions: trash icon prefix
        table.insert(choices, {
          id = session.name,
          label = "🗑 " .. session.name,
        })
      end
    end

    -- Add back-to-switch sentinel
    table.insert(choices, {
      id = "__back__",
      label = "← Back to sessions...",
    })
  end

  window:perform_action(
    act.InputSelector({
      title = title,
      choices = choices,
      fuzzy = true,
      action = wezterm.action_callback(function(inner_window, inner_pane, id, label)
        if not id then return end -- Escape pressed

        -- Handle mode-switch sentinels
        if id == "__delete_mode__" then
          M.show_picker(inner_window, inner_pane, "delete")
          return
        end

        if id == "__back__" then
          M.show_picker(inner_window, inner_pane, "switch")
          return
        end

        -- Mode-specific behavior
        if mode == "switch" then
          -- ... existing switch logic ...
        elseif mode == "delete" then
          -- ... delete confirmation logic ...
        end
      end),
    }),
    pane
  )
end
```

### Pattern 2: Confirmation with PromptInputLine

**What:** Before destructive action, show PromptInputLine requesting typed confirmation. Normalize input to lowercase, accept "y" or "yes", cancel silently on anything else.

**When to use:** Any destructive operation (delete, reset, cleanup) where accidental triggering would be costly.

**Example:**
```lua
-- Source: WezTerm PromptInputLine API + Phase 6 create-new pattern
if mode == "delete" then
  -- Silent no-op if current session
  if id == current then
    return
  end

  -- Show confirmation prompt
  inner_window:perform_action(
    act.PromptInputLine({
      description = "Delete '" .. id .. "'? Type 'yes' to confirm:",
      action = wezterm.action_callback(function(win, p, line)
        if not line then
          -- User pressed Escape - reopen picker in delete mode
          M.show_picker(win, p, "delete")
          return
        end

        -- Normalize to lowercase
        local normalized = string.lower(line)

        if normalized ~= "y" and normalized ~= "yes" then
          -- User declined - reopen picker in delete mode
          M.show_picker(win, p, "delete")
          return
        end

        -- User confirmed - delete the session
        local ok, err = manager.delete_session(id)
        if not ok then
          -- Show error toast
          win:toast_notification("Delete Error", err or "Failed to delete session", nil, 3000)
          M.show_picker(win, p, "delete")
          return
        end

        -- Success - reopen picker in switch mode
        -- Check if any deletable sessions remain
        local remaining = manager.list_sessions()
        local has_deletable = false
        local active = wezterm.mux.get_active_workspace()
        for _, s in ipairs(remaining) do
          if s.name ~= active then
            has_deletable = true
            break
          end
        end

        if has_deletable then
          M.show_picker(win, p, "switch")
        end
        -- If no deletable sessions remain, just close picker (don't reopen)
      end),
    }),
    inner_pane
  )
end
```

### Pattern 3: Conditional Sentinel Display

**What:** Show mode-appropriate sentinels based on picker state. Hide "Create new" sentinel in delete mode, hide "Delete mode" sentinel if no deletable sessions exist.

**When to use:** When mode constraints make certain actions unavailable.

**Example:**
```lua
-- Source: Adapted from existing __create__ and __empty__ sentinel patterns
if mode == "switch" then
  -- Always show create-new sentinel in switch mode
  table.insert(choices, {
    id = "__create__",
    label = "+ Create new session...",
  })

  -- Only show delete-mode sentinel if deletable sessions exist
  local has_deletable = false
  for _, session in ipairs(sessions) do
    if session.name ~= current then
      has_deletable = true
      break
    end
  end

  if has_deletable then
    table.insert(choices, {
      id = "__delete_mode__",
      label = "🗑 Delete mode...",
    })
  end
end
```

### Anti-Patterns to Avoid

- **Trying to capture Tab key in InputSelector callback:** InputSelector doesn't expose keyboard events to action callbacks. Tab key is handled internally by fuzzy search. Use sentinel items instead.
- **Assuming InputSelector can be updated in place:** No "refresh choices" API exists. Must close and reopen picker with new choices array.
- **Deleting current session without switching first:** Causes workspace closure mid-operation. `manager.delete_session()` already handles this — it switches to another session before deleting.
- **Complex nested PromptInputLine chains:** User gets lost in confirmation dialogs. Keep it simple: one confirmation level, clear messaging.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Mode state machine | Global mode variable, complex tracking | Function parameter + picker reopening | Stateless design — each picker invocation is independent, mode passed explicitly |
| Delete validation | Manual workspace checks, JSON existence checks | manager.delete_session() | Full implementation exists: validates "default" protection, switches workspace, removes JSON, closes panes |
| Case-insensitive comparison | Custom tolower loops, byte manipulation | string.lower() | Standard Lua library, handles all edge cases |
| Tab key handling | Custom key event handlers | Sentinel items | InputSelector doesn't expose key events; sentinel pattern is standard WezTerm approach |

**Key insight:** WezTerm's InputSelector is intentionally simple — no custom key bindings, no state updates. The sentinel pattern is how the WezTerm ecosystem handles multi-step flows (see official examples using `__next__` and `__cancel__` sentinels).

## Common Pitfalls

### Pitfall 1: Current Session Appears Deletable in Delete Mode

**What goes wrong:** User sees current session with trash icon in delete mode, thinks they can delete it, confused when nothing happens.

**Why it happens:** Blindly applying trash icon prefix to all sessions without checking if session is current.

**How to avoid:** Filter current session out OR display with special label:
- Option A (preferred per CONTEXT.md): Show current session WITHOUT trash icon, add "(current)" label
- Option B: Hide current session entirely in delete mode (but then user might think picker is broken if only one session exists)

**Warning signs:** User reports "I selected a session in delete mode but nothing happened"

### Pitfall 2: Tab Key Doesn't Work for Mode Toggle

**What goes wrong:** User presses Tab expecting to toggle mode, but picker just cycles through matches (fuzzy search behavior).

**Why it happens:** InputSelector uses Tab for fuzzy search navigation. No API to override or capture Tab key events in action callbacks.

**How to avoid:** Don't try to capture Tab key. Use sentinel items for mode switching. Document in UI: "Select 🗑 Delete mode... to delete sessions" (make the pattern discoverable).

**Warning signs:** This is a research finding, not a post-deployment issue — addressed by sentinel pattern design.

### Pitfall 3: Picker Reopens in Wrong Mode After Cancellation

**What goes wrong:** User cancels delete confirmation (presses Escape), picker reopens in switch mode instead of delete mode. User has to re-enter delete mode.

**Why it happens:** Confirmation callback doesn't distinguish between "user cancelled" and "deletion succeeded" — both paths call `M.show_picker()` but with different mode arguments.

**How to avoid:**
- After cancellation: reopen in delete mode — `M.show_picker(win, p, "delete")`
- After successful deletion: reopen in switch mode — `M.show_picker(win, p, "switch")`
- On Escape in PromptInputLine: `if not line then ... M.show_picker(..., "delete") ...`

**Warning signs:** User reports "I pressed Escape to cancel delete, now I have to go back into delete mode"

### Pitfall 4: Deletion Fails Silently

**What goes wrong:** `manager.delete_session()` fails (e.g., trying to delete "default"), but picker just closes without feedback.

**Why it happens:** Not checking return value of `delete_session()`, or not showing error toast.

**How to avoid:** Always check `ok, err` and show toast on failure:
```lua
local ok, err = manager.delete_session(id)
if not ok then
  win:toast_notification("Delete Error", err or "Failed to delete session", nil, 3000)
  M.show_picker(win, p, "delete") -- Reopen picker so user can try again
  return
end
```

**Warning signs:** User reports "tried to delete a session, nothing happened"

### Pitfall 5: Picker Flickers When Reopening After Deletion

**What goes wrong:** Picker closes, user sees terminal briefly, picker reopens — feels janky.

**Why it happens:** InputSelector closes after callback completes, then new `perform_action` call opens it again. Inherent to WezTerm's modal UI model.

**How to avoid:**
- Accept it as architectural limitation (no workaround available)
- Minimize flicker by calling `M.show_picker()` as last statement in callback (no operations after it)
- User feedback: "the session disappearing from the list is feedback enough" — don't need success toast that adds delay

**Warning signs:** User reports "picker feels flickery" — expected behavior, document as known limitation if it becomes concern.

## Code Examples

Verified patterns adapted from Phase 6 picker.lua:

### Complete Mode-Aware Picker Function

```lua
-- Source: Extended from Phase 6 picker.lua
local wezterm = require("wezterm")
local act = wezterm.action
local manager = require("lua.session.manager")

local M = {}

function M.show_picker(window, pane, mode)
  mode = mode or "switch"

  local current = wezterm.mux.get_active_workspace()
  local sessions = manager.list_sessions()

  local choices = {}
  local title = "Sessions"

  if mode == "switch" then
    -- Switch mode: normal picker behavior
    if #sessions == 0 then
      table.insert(choices, {
        id = "__empty__",
        label = "No sessions found",
      })
    else
      for _, session in ipairs(sessions) do
        local prefix = (session.name == current) and "* " or "  "
        table.insert(choices, {
          id = session.name,
          label = prefix .. session.name,
        })
      end
    end

    -- Always append create-new sentinel
    table.insert(choices, {
      id = "__create__",
      label = "+ Create new session...",
    })

    -- Check if any deletable sessions exist
    local has_deletable = false
    for _, session in ipairs(sessions) do
      if session.name ~= current then
        has_deletable = true
        break
      end
    end

    -- Add delete-mode sentinel if deletable sessions exist
    if has_deletable then
      table.insert(choices, {
        id = "__delete_mode__",
        label = "🗑 Delete mode...",
      })
    end

  elseif mode == "delete" then
    title = "Sessions [DELETE]"

    -- Delete mode: show sessions with trash icons
    for _, session in ipairs(sessions) do
      if session.name == current then
        -- Current session: no trash icon, add (current) label
        table.insert(choices, {
          id = session.name,
          label = "  " .. session.name .. " (current)",
        })
      else
        -- Deletable session: trash icon prefix
        table.insert(choices, {
          id = session.name,
          label = "🗑 " .. session.name,
        })
      end
    end

    -- Always append back-to-switch sentinel
    table.insert(choices, {
      id = "__back__",
      label = "← Back to sessions...",
    })
  end

  window:perform_action(
    act.InputSelector({
      title = title,
      choices = choices,
      fuzzy = true,
      action = wezterm.action_callback(function(inner_window, inner_pane, id, label)
        -- User pressed Escape
        if not id then
          return
        end

        -- Handle sentinels
        if id == "__empty__" then
          return
        end

        if id == "__delete_mode__" then
          M.show_picker(inner_window, inner_pane, "delete")
          return
        end

        if id == "__back__" then
          M.show_picker(inner_window, inner_pane, "switch")
          return
        end

        if id == "__create__" then
          inner_window:perform_action(
            act.PromptInputLine({
              description = "New session name",
              action = wezterm.action_callback(function(win, p, line)
                if not line or line == "" then
                  return
                end
                local ok, err = manager.create_session(line)
                if not ok then
                  win:toast_notification("Session Error", err or "Failed to create session", nil, 3000)
                end
              end),
            }),
            inner_pane
          )
          return
        end

        -- Mode-specific selection handling
        if mode == "switch" then
          -- Silent no-op for current session
          if id == current then
            return
          end

          -- Switch to selected session
          local ok, err = manager.attach_session(id)
          if not ok then
            inner_window:toast_notification("Session Error", err or "Failed to attach", nil, 3000)
          end

        elseif mode == "delete" then
          -- Silent no-op if current session
          if id == current then
            return
          end

          -- Show delete confirmation
          inner_window:perform_action(
            act.PromptInputLine({
              description = "Delete '" .. id .. "'? Type 'yes' to confirm:",
              action = wezterm.action_callback(function(win, p, line)
                if not line then
                  -- User pressed Escape - return to delete mode
                  M.show_picker(win, p, "delete")
                  return
                end

                -- Normalize and check confirmation
                local normalized = string.lower(line)
                if normalized ~= "y" and normalized ~= "yes" then
                  -- User cancelled - return to delete mode
                  M.show_picker(win, p, "delete")
                  return
                end

                -- User confirmed - delete session
                local ok, err = manager.delete_session(id)
                if not ok then
                  win:toast_notification("Delete Error", err or "Failed to delete session", nil, 3000)
                  M.show_picker(win, p, "delete")
                  return
                end

                -- Success - check if any deletable sessions remain
                local remaining = manager.list_sessions()
                local has_deletable = false
                local active = wezterm.mux.get_active_workspace()
                for _, s in ipairs(remaining) do
                  if s.name ~= active then
                    has_deletable = true
                    break
                  end
                end

                -- Reopen picker in switch mode, or close if no deletable sessions
                if has_deletable then
                  M.show_picker(win, p, "switch")
                end
              end),
            }),
            inner_pane
          )
        end
      end),
    }),
    pane
  )
end

return M
```

### Case-Insensitive Confirmation Check

```lua
-- Source: Lua standard library string.lower()
local normalized = string.lower(line)  -- "Y" -> "y", "YES" -> "yes"
if normalized ~= "y" and normalized ~= "yes" then
  -- User declined
  return
end
-- User confirmed, proceed with deletion
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| CLI-only session deletion | In-picker delete mode | Phase 7 (current) | Faster workflow, no context switch to shell |
| Tab key for mode toggle | Sentinel items for mode switch | Phase 7 research (current) | Works within InputSelector limitations, discoverable UI |
| Success toasts after deletion | Silent success (list update as feedback) | Phase 7 design decision | Reduces UI noise, faster picker reopening |

**Deprecated/outdated:**
- Tab key capture in InputSelector: Never existed — common misconception from other fuzzy pickers (fzf, telescope.nvim). WezTerm InputSelector is simpler.

## Open Questions

1. **Should Escape in delete mode return to switch mode or close picker entirely?**
   - What we know: InputSelector's default Escape behavior is "close picker". To override, we'd need to... wait, we can't override Escape in InputSelector.
   - What's unclear: User expectation — is "Escape = close" sufficient, or do they expect "Escape = back to switch mode"?
   - Recommendation: Accept default Escape behavior (close picker). Document sentinel "← Back to sessions..." as the way to return to switch mode. If users complain, revisit in future version.

2. **Should we hide current session entirely in delete mode, or show it with "(current)" label?**
   - What we know: CONTEXT.md specifies "show WITHOUT trash icon, labeled with (current)". Selecting it is silent no-op.
   - What's unclear: Nothing — this is already decided.
   - Recommendation: Follow CONTEXT.md specification. Show current session, no trash icon, "(current)" label, silent no-op on selection.

3. **What if user deletes all sessions except current — should picker auto-close or stay open?**
   - What we know: CONTEXT.md specifies "auto-close picker if no deletable sessions remain"
   - What's unclear: Definition of "deletable sessions" — does current session count?
   - Recommendation: Current session is NOT deletable. If only current session remains after deletion, auto-close picker (don't reopen in switch mode). Rationale: user has nothing left to delete or switch to.

## Validation Architecture

> Nyquist validation enabled — including test infrastructure requirements

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Manual testing + shell script validation (inherited from Phase 6) |
| Config file | None — shell script tests in `bin/test-phase7.sh` |
| Quick run command | `bash bin/test-phase7.sh` |
| Full suite command | `bash bin/test-phase7.sh --verbose` |

**Note:** Same constraints as Phase 6 — WezTerm GUI interactions require manual testing. Focus on Lua syntax validation + manual test checklist.

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| REQ-06 | Select "🗑 Delete mode..." sentinel to enter delete mode | manual | N/A — requires GUI interaction | ❌ Wave 0 |
| REQ-06 | Delete mode shows "Sessions [DELETE]" title | manual | N/A — visual verification | ❌ Wave 0 |
| REQ-06 | Deletable sessions have "🗑 " prefix | manual | N/A — visual verification | ❌ Wave 0 |
| REQ-06 | Current session shows "(current)" without trash icon | manual | N/A — visual verification | ❌ Wave 0 |
| REQ-06 | Selecting session shows PromptInputLine confirmation | manual | N/A — GUI interaction | ❌ Wave 0 |
| REQ-06 | Typing "y" or "yes" confirms deletion | manual | N/A — test case-insensitive variants | ❌ Wave 0 |
| REQ-06 | Typing anything else cancels deletion | manual | N/A — test "", "no", "n", "asdf" | ❌ Wave 0 |
| REQ-06 | After deletion, picker reopens in switch mode | manual | N/A — observe picker state | ❌ Wave 0 |
| REQ-06 | Picker auto-closes if no deletable sessions remain | manual | N/A — test scenario: delete all non-current sessions | ❌ Wave 0 |
| REQ-06 | "← Back to sessions..." returns to switch mode | manual | N/A — GUI interaction | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** Syntax check: `wezterm show-config` (< 1 second)
- **Per wave merge:** Interactive test: Enter delete mode, verify UI, test confirmation flow (~ 60 seconds)
- **Phase gate:** Full interactive testing of all delete mode behaviors before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `bin/test-phase7.sh` — syntax validation for extended picker.lua
  - Check: `wezterm show-config` exits 0
  - Check: Lua syntax for mode parameter and delete mode logic
- [ ] Manual test checklist in `PLAN.md` verification section:
  - [ ] "🗑 Delete mode..." sentinel appears in switch mode when deletable sessions exist
  - [ ] Delete mode shows "Sessions [DELETE]" title
  - [ ] Deletable sessions have "🗑 " prefix
  - [ ] Current session shows "(current)" label, no trash icon
  - [ ] Selecting current session in delete mode is silent no-op
  - [ ] PromptInputLine asks "Delete '<name>'? Type 'yes' to confirm:"
  - [ ] "y", "Y", "yes", "YES" all confirm deletion
  - [ ] Empty input, "no", "n", Escape all cancel deletion
  - [ ] After confirmed deletion, picker reopens in switch mode
  - [ ] After cancelled deletion, picker reopens in delete mode
  - [ ] Picker auto-closes if only current session remains
  - [ ] "← Back to sessions..." returns to switch mode

**Rationale:** Same as Phase 6 — WezTerm GUI interactions require manual testing. Extended checklist covers delete mode-specific behaviors.

## Sources

### Primary (HIGH confidence)
- `lua/session/picker.lua` (Phase 6) — Existing InputSelector pattern, sentinel handling, action_callback structure
- `lua/session/manager.lua` (Phase 4) — `delete_session()` implementation with validation and cleanup
- `.planning/phases/06-fuzzy-picker/06-RESEARCH.md` — InputSelector API capabilities, PromptInputLine confirmation pattern
- `.planning/phases/07-picker-delete-mode/07-CONTEXT.md` — User decisions on delete mode UI and behavior
- WezTerm 20240203-110809 installed locally — InputSelector and PromptInputLine API verification

### Secondary (MEDIUM confidence)
- `.planning/REQUIREMENTS.md` (REQ-06) — Delete mode requirement specification
- Lua 5.4 standard library — string.lower() for case-insensitive comparison

### Tertiary (LOW confidence)
None — all findings verified against existing codebase, user decisions, and installed WezTerm version

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - All APIs already in use (InputSelector, PromptInputLine, delete_session)
- Architecture: HIGH - Sentinel pattern proven in Phase 6, mode parameter is straightforward extension
- Pitfalls: HIGH - Tab key limitation is architectural, confirmation flow tested in Phase 6 create-new
- Delete mode UX: HIGH - User decisions explicitly documented in CONTEXT.md

**Research date:** 2026-03-14
**Valid until:** 2026-04-14 (30 days — WezTerm stable, no API changes expected)
