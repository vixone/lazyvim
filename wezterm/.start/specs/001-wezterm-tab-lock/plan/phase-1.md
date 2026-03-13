---
title: "Phase 1: Tab Lock Feature"
status: completed
version: "1.0"
phase: 1
---

# Phase 1: Tab Lock Feature

## Phase Context

**GATE**: Read all referenced files before starting this phase.

**Specification References**:
- `[ref: SDD/Solution Strategy]` — Architecture: event-driven callbacks + wezterm.GLOBAL state
- `[ref: SDD/Building Block View]` — Component diagram: 5 components, all in wezterm.lua
- `[ref: SDD/Implementation Examples]` — Complete Lua code examples for all tasks
- `[ref: SDD/Runtime View]` — Flow sequences for lock, blocked close, normal close
- `[ref: SDD/Implementation Gotchas]` — tostring on tab_id, GLOBAL init pattern, syntax checking

**Key Decisions**:
- ADR-1: `wezterm.GLOBAL.locked_tabs` for state (not user vars or file)
- ADR-5: String return from `format-tab-title` (not FormatItem table) to preserve theme colors

**Dependencies**:
- None — this is Phase 1 (and only phase)

---

## Tasks

Delivers the complete tab lock feature: state management, close protection, visual indicator, and status hint.

- [x] **T1.1 Tab lock state + toggle keybinding** `[activity: backend-logic]`

  1. Prime: Read SDD Implementation Examples: "Toggle Lock Callback" `[ref: SDD/Implementation Examples; lines: toggle-lock]`. Read current keybinding section in wezterm.lua `[ref: wezterm.lua; lines: 167-372]`
  2. Test: (Manual) Press CMD+SHIFT+L → toast "Tab Locked" appears. Press CMD+SHIFT+L again → toast "Tab Unlocked" appears. Verify no conflict with existing keybindings.
  3. Implement: Add CMD+SHIFT+L keybinding with `action_callback` that initializes `wezterm.GLOBAL.locked_tabs` if nil, toggles `locked_tabs[tostring(tab_id)]` between `true` and `nil`, and shows toast feedback. Place in KEYBINDINGS section after existing tab management bindings.
  4. Validate: Reload config (CMD+CTRL+,). Toggle lock on/off multiple times. Verify toast appears each time. Verify no errors in WezTerm error log.
  5. Success:
     - [ ] CMD+SHIFT+L locks an unlocked tab with toast confirmation `[ref: PRD/Feature 1/AC-1]`
     - [ ] CMD+SHIFT+L unlocks a locked tab with toast confirmation `[ref: PRD/Feature 1/AC-2]`
     - [ ] New tabs are unlocked by default `[ref: PRD/Feature 1/AC-3]`

- [x] **T1.2 Close guards for CMD+W and CMD+SHIFT+W** `[activity: backend-logic]`

  1. Prime: Read SDD Implementation Examples: "Close Guard Callback" `[ref: SDD/Implementation Examples; lines: close-guard]`. Read SDD Error Handling `[ref: SDD/Runtime View/Error Handling]`. Read current close keybindings `[ref: wezterm.lua; lines: 214-226]`.
  2. Test: (Manual) Lock a tab → press CMD+W → toast "Tab Locked" appears, pane stays open. Lock a tab → press CMD+SHIFT+W → toast appears, tab stays open. Unlock tab → press CMD+W → pane closes normally.
  3. Implement: Replace the existing CMD+W binding (line 215-219) with `action_callback` that checks `wezterm.GLOBAL.locked_tabs[tostring(tab_id)]`. If locked: `toast_notification` + return. If unlocked: `window:perform_action(act.CloseCurrentPane({confirm=false}), pane)`. Same pattern for CMD+SHIFT+W (line 222-226) with `CloseCurrentTab`.
  4. Validate: Reload config. Test all 4 scenarios: locked+CMD+W (blocked), locked+CMD+SHIFT+W (blocked), unlocked+CMD+W (closes pane), unlocked+CMD+SHIFT+W (closes tab). Verify toast message includes unlock instructions.
  5. Success:
     - [ ] CMD+W blocked on locked tab with toast `[ref: PRD/Feature 2/AC-1]`
     - [ ] CMD+SHIFT+W blocked on locked tab with toast `[ref: PRD/Feature 2/AC-2]`
     - [ ] CMD+W works normally on unlocked tab `[ref: PRD/Feature 2/AC-3]`
     - [ ] CMD+SHIFT+W works normally on unlocked tab `[ref: PRD/Feature 2/AC-4]`

- [x] **T1.3 Visual lock indicator in tab bar** `[parallel: true]` `[activity: frontend-ui]`

  1. Prime: Read SDD Implementation Examples: "Format Tab Title with Lock Icon" `[ref: SDD/Implementation Examples; lines: format-tab-title]`. Read SDD ADR-5 on string return approach `[ref: SDD/Architecture Decisions/ADR-5]`.
  2. Test: (Manual) Lock a tab → lock icon (fa_lock) appears in tab title. Unlock → icon disappears. Verify icon shows on both active and inactive locked tabs. Verify existing Catppuccin theme colors still apply.
  3. Implement: Add `wezterm.on("format-tab-title", ...)` event handler. Read `wezterm.GLOBAL.locked_tabs`, prepend `wezterm.nerdfonts.fa_lock .. " "` to title for locked tabs. Return simple string (not FormatItem table) to preserve theme colors. Account for lock icon width in `wezterm.truncate_right` calculation. Place near existing `update-status` handler.
  4. Validate: Reload config. Lock/unlock tabs. Verify icon appears/disappears. Check both active and inactive tab states. Verify tab titles don't overflow `tab_max_width`.
  5. Success:
     - [ ] Locked tab shows lock icon prefix `[ref: PRD/Feature 3/AC-1]`
     - [ ] Unlocked tab shows no lock icon `[ref: PRD/Feature 3/AC-2]`
     - [ ] Lock icon visible on both active and inactive tabs `[ref: PRD/Feature 3/AC-3]`

- [x] **T1.4 Status bar lock hint** `[parallel: true]` `[activity: frontend-ui]`

  1. Prime: Read current status hints implementation `[ref: wezterm.lua; lines: 387-407]`. Read SDD Implementation Examples: "Updated Status Hints" `[ref: SDD/Implementation Examples; lines: status-hints]`.
  2. Test: (Manual) Look at right status area → "⇧⌘L Lock" appears alongside existing hints.
  3. Implement: Add `{ key = "⇧⌘L", label = "Lock" }` entry to the `hints` table in the existing `update-status` handler. Place after RenameTab and before DailyNote for logical grouping.
  4. Validate: Reload config. Verify hint appears in status bar. Verify existing hints still display correctly. Verify hints don't overflow available space.
  5. Success:
     - [ ] Lock toggle shortcut visible in status bar hints `[ref: PRD/Feature 4/AC-1]`

- [ ] **T1.5 End-to-end validation** `[activity: validate]`

  Run complete end-to-end test scenario:
  1. Open 3 tabs. Lock tab 2.
  2. Verify tab 2 shows lock icon. Tabs 1 and 3 do not.
  3. Switch to tab 2, press CMD+W → blocked with toast. Tab stays open.
  4. Switch to tab 2, press CMD+SHIFT+W → blocked with toast. Tab stays open.
  5. Switch to tab 1, press CMD+W → closes normally.
  6. Unlock tab 2 (CMD+SHIFT+L). Lock icon disappears.
  7. Press CMD+W on tab 2 → closes normally.
  8. Reload config (CMD+CTRL+,). Verify lock state on any remaining locked tab survives reload.
  9. Verify status bar hints show "⇧⌘L Lock".
  10. Verify theme colors are correct on all tabs (dark and light mode if testing both).
