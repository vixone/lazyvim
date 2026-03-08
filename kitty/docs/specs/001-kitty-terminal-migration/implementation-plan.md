---
title: "Kitty Terminal Migration — Implementation Plan"
status: draft
version: "1.0"
---

# Implementation Plan

## Validation Checklist

### CRITICAL GATES (Must Pass)

- [x] All `[NEEDS CLARIFICATION]` markers have been addressed
- [x] All specification file paths are correct and exist
- [x] Each phase follows TDD: Prime → Test → Implement → Validate
- [x] Every task has verifiable success criteria
- [x] A developer could follow this plan independently

### QUALITY CHECKS (Should Pass)

- [x] Context priming section is complete
- [x] All implementation phases are defined
- [x] Dependencies between phases are clear (no circular dependencies)
- [x] Parallel work is properly tagged with `[parallel: true]`
- [x] Activity hints provided for specialist selection
- [x] Every phase references relevant SDD sections
- [x] Every test references PRD acceptance criteria
- [x] Integration & E2E tests defined in final phase
- [x] Project commands match actual project setup

---

## Context Priming

*GATE: Read all files in this section before starting any implementation.*

**Specification**:
- `docs/specs/001-kitty-terminal-migration/product-requirements.md` — Product Requirements
- `docs/specs/001-kitty-terminal-migration/solution-design.md` — Solution Design (primary reference)

**Key Design Decisions**:
- **ADR-1**: Multi-file config — `kitty.conf` is the root; it `include`s `theme.conf` and `keybindings.conf`
- **ADR-2**: Tokyonight Night — use exact hex values from SDD `theme.conf` spec; do NOT approximate
- **ADR-3**: Context-aware `Cmd+arrows` — `neighboring_window` action; silently no-ops when no neighbor
- **ADR-4**: Overlay kitten — `launch --type=overlay --location=center` bound to `Cmd+F`; requires `allow_remote_control yes`
- **ADR-5**: Zellij dropped — no hybrid config, no Zellij dependency anywhere

**Implementation Context**:
```bash
# Reload config (no restart needed for most changes)
Reload:   Ctrl+Shift+F5

# Verify config syntax before applying
Debug:    kitty --config ~/.config/kitty/kitty.conf --debug-config 2>&1 | head -50

# Check font availability (must run before T1.1)
Fonts:    kitty +list-fonts | grep -i roboto

# Inspect running Kitty state
Inspect:  kitty @ ls

# Verify shell integration is active (run inside Kitty)
Check:    echo $KITTY_SHELL_INTEGRATION

# Verify true color support
Color:    printf '\x1b[38;2;118;162;247mBlue\x1b[0m\n'
```

---

## Implementation Phases

Each task follows red-green-refactor: **Prime** (understand context), **Test** (red), **Implement** (green), **Validate** (refactor + verify).

---

### Phase 1: Config Foundation

Establishes the root `kitty.conf` with font, display, performance, and layout settings — the skeleton all other phases plug into.

- [ ] **T1.1 Verify Font Availability** `[activity: validate]`

  1. Prime: Read SDD font spec `[ref: SDD/Interface Specifications/kitty.conf; font_family section]`
  2. Test: Run `kitty +list-fonts | grep -i roboto` — confirm `RobotoMono Nerd Font Mono` appears in output
  3. Implement: If font is missing, install via `brew install --cask font-roboto-mono-nerd-font`; re-verify
  4. Validate: Font string appears exactly as `RobotoMono Nerd Font Mono` in font list output
  5. Success: Font available for use in `kitty.conf` `[ref: PRD/Feature 2]`

- [ ] **T1.2 Create root `kitty.conf`** `[activity: build-feature]`

  1. Prime: Read SDD `kitty.conf` section structure `[ref: SDD/Interface Specifications/kitty.conf sections]`; read `[ref: SDD/Cross-Cutting/Implementation Gotchas]`
  2. Test: Open `kitty.conf` in editor — expect file doesn't exist yet; after creation, `kitty --debug-config` should report no errors
  3. Implement: Create `~/.config/kitty/kitty.conf` with the following sections (no theme/keybinding content — those go in subfiles):
     ```
     # FONTS
     font_family      RobotoMono Nerd Font Mono
     bold_font        auto
     italic_font      auto
     bold_italic_font auto
     font_size        16.0

     # DISPLAY
     window_padding_width  8
     tab_bar_style         powerline
     tab_powerline_style   angled
     tab_title_template    "{index}: {title}"
     tab_bar_min_tabs      2
     active_tab_font_style     bold
     inactive_tab_font_style   normal

     # SCROLLBACK
     scrollback_lines  4000
     scrollback_pager  less +G -R

     # BELLS & CURSOR
     enable_audio_bell       no
     visual_bell_duration    0
     cursor_blink_interval   0

     # PERFORMANCE
     sync_to_monitor  yes
     input_delay      0
     repaint_delay    10

     # LAYOUTS
     enabled_layouts  tall,fat,grid,stack

     # SHELL INTEGRATION
     shell_integration  enabled

     # REMOTE CONTROL (required for overlay)
     allow_remote_control  yes
     listen_on             unix:@kitty

     # INCLUDES
     include theme.conf
     include keybindings.conf
     ```
  4. Validate: `kitty --debug-config` exits cleanly; font renders at 16pt in a new Kitty window
  5. Success:
     - [ ] Font renders as RobotoMono Nerd Font Mono at 16pt `[ref: PRD/AC-Font-1]`
     - [ ] No config parse errors reported `[ref: SDD/Project Commands]`
     - [ ] `allow_remote_control yes` present (required for overlay) `[ref: SDD/Gotchas #1]`

- [ ] **T1.3 Phase 1 Validation** `[activity: validate]`

  - Reload Kitty with `Ctrl+Shift+F5`
  - Confirm font renders correctly (no monospace fallback)
  - Confirm `kitty --debug-config` reports zero errors
  - Note: theme.conf and keybindings.conf will be missing — Kitty will log warnings but not fail; this is expected at this phase

---

### Phase 2: Tokyonight Night Theme

Delivers the complete color palette matching LazyVim's default Tokyonight Night theme.

- [ ] **T2.1 Create `theme.conf`** `[activity: build-feature]`

  1. Prime: Read full color palette spec `[ref: SDD/Interface Specifications/theme.conf]`; note the LazyVim background hex `#1a1b26` — this must match exactly for zero visual seam
  2. Test: Before creating, open LazyVim in current Kitty window — observe color mismatch as baseline. After applying, the mismatch should be eliminated.
  3. Implement: Create `~/.config/kitty/theme.conf` with ALL values from the SDD palette:
     ```
     # Tokyonight Night — matched to folke/tokyonight.nvim
     background            #1a1b26
     foreground            #c0caf5
     cursor                #c0caf5
     cursor_text_color     #1a1b26
     url_color             #73daca
     selection_background  #283457
     selection_foreground  #c0caf5

     # Tab bar colors
     active_tab_background    #7aa2f7
     active_tab_foreground    #1a1b26
     inactive_tab_background  #1a1b26
     inactive_tab_foreground  #565f89
     tab_bar_background       #15161e

     # ANSI — Normal (color0–color7)
     color0   #15161e
     color1   #f7768e
     color2   #9ece6a
     color3   #e0af68
     color4   #7aa2f7
     color5   #bb9af7
     color6   #7dcfff
     color7   #a9b1d6

     # ANSI — Bright (color8–color15)
     color8   #414868
     color9   #f7768e
     color10  #9ece6a
     color11  #e0af68
     color12  #7aa2f7
     color13  #bb9af7
     color14  #7dcfff
     color15  #c0caf5
     ```
  4. Validate: Reload Kitty (`Ctrl+Shift+F5`); terminal background becomes `#1a1b26`; open LazyVim and verify zero visible seam between terminal background and editor background
  5. Success:
     - [ ] Kitty background matches LazyVim Tokyonight Night background (no visible seam) `[ref: PRD/AC-Theme-1]`
     - [ ] Colored output (e.g. `ls --color`) uses Tokyonight palette, not default grey `[ref: PRD/AC-Theme-2]`
     - [ ] Cursor renders in `#c0caf5` `[ref: PRD/AC-Theme-4]`

- [ ] **T2.2 Phase 2 Validation** `[activity: validate]`

  - Run `printf '\x1b[38;2;122;162;247mBlue\x1b[0m\n'` — output should be Tokyonight blue (#7aa2f7), not default terminal blue
  - Open LazyVim: confirm no color seam at background boundary
  - Open a new tab: confirm tab bar shows powerline style with correct active/inactive colors

---

### Phase 3: Keybindings

Delivers the full keybinding scheme — pane splitting, navigation, tab management, overlay, and layout cycling.

- [ ] **T3.1 Create `keybindings.conf`** `[activity: build-feature]`

  1. Prime: Read full keybinding spec `[ref: SDD/Interface Specifications/keybindings.conf]`; read navigation trace `[ref: SDD/Context-Aware Navigation Walkthrough]`; note gotcha — `Cmd+W` closes pane OR tab depending on pane count `[ref: SDD/Gotchas #4]`
  2. Test: Before creating, verify `Cmd+D` in current Kitty does nothing (or triggers macOS default). After applying, it should split the pane.
  3. Implement: Create `~/.config/kitty/keybindings.conf` with all directives from SDD spec:
     ```
     # --- PANE MANAGEMENT ---
     map cmd+d          launch --location=vsplit
     map cmd+shift+d    launch --location=hsplit
     map cmd+w          close_window
     map cmd+shift+w    close_tab

     # --- PANE NAVIGATION (neighboring_window: no-op if no neighbor) ---
     map cmd+left       neighboring_window left
     map cmd+right      neighboring_window right
     map cmd+up         neighboring_window up
     map cmd+down       neighboring_window down

     # --- TAB NAVIGATION ---
     map cmd+t          new_tab
     map cmd+1          goto_tab 1
     map cmd+2          goto_tab 2
     map cmd+3          goto_tab 3
     map cmd+4          goto_tab 4
     map cmd+5          goto_tab 5
     map cmd+6          goto_tab 6
     map cmd+7          goto_tab 7
     map cmd+8          goto_tab 8
     map cmd+9          goto_tab 9
     map cmd+shift+]    next_tab
     map cmd+shift+[    previous_tab

     # --- LAYOUT ---
     map cmd+l          next_layout

     # --- OVERLAY / FLOATING PANE ---
     map cmd+f          launch --type=overlay --location=center --title=overlay zsh

     # --- ZOOM (stack layout toggle) ---
     map cmd+shift+f    toggle_layout stack

     # --- OS WINDOW ---
     map cmd+n          new_os_window

     # --- SCROLLBACK & HINTS ---
     map cmd+shift+h    show_scrollback
     map cmd+e          launch --type=overlay kitty +kitten hints
     ```
  4. Validate: Reload Kitty (`Ctrl+Shift+F5`); test each binding manually per T3.2
  5. Success:
     - [ ] `Cmd+D` opens vsplit `[ref: PRD/AC-Pane-1]`
     - [ ] `Cmd+Shift+D` opens hsplit `[ref: PRD/AC-Pane-2]`
     - [ ] `Cmd+W` closes active pane `[ref: PRD/AC-Pane-3]`
     - [ ] `Cmd+arrows` moves focus to neighbor pane `[ref: PRD/AC-Nav-1]`
     - [ ] `Cmd+F` opens overlay shell `[ref: PRD/AC-Overlay-1]`
     - [ ] `Cmd+L` cycles layout `[ref: PRD/AC-Layout-1]`

- [ ] **T3.2 Verify Each Keybinding** `[activity: validate]`

  Manually exercise every binding after reload. Check against this list:

  | Binding | Expected Action | ✓/✗ |
  |---------|----------------|-----|
  | `Cmd+D` | New pane right (vsplit) | |
  | `Cmd+Shift+D` | New pane below (hsplit) | |
  | `Cmd+W` | Close active pane | |
  | `Cmd+Shift+W` | Close active tab | |
  | `Cmd+Right` | Focus right pane (or no-op) | |
  | `Cmd+Left` | Focus left pane (or no-op) | |
  | `Cmd+Up` | Focus pane above (or no-op) | |
  | `Cmd+Down` | Focus pane below (or no-op) | |
  | `Cmd+T` | New tab | |
  | `Cmd+1` through `Cmd+9` | Jump to tab N | |
  | `Cmd+Shift+]` | Next tab | |
  | `Cmd+Shift+[` | Previous tab | |
  | `Cmd+L` | Cycle layout (tall→fat→grid→stack) | |
  | `Cmd+F` | Open overlay shell (centered) | |
  | `Cmd+Shift+F` | Toggle stack (zoom) layout | |
  | `Cmd+N` | New OS window | |
  | `Cmd+Shift+H` | Open scrollback pager | |
  | `Cmd+E` | Open hints kitten overlay | |

  Note any failures — if a `Cmd+*` binding is silently overridden by macOS, go to System Settings → Keyboard → Shortcuts and remove the conflicting system shortcut.

---

### Phase 4: Shell Integration Verification

Confirms shell integration is active and CWD inheritance works for new panes and overlays.

- [ ] **T4.1 Verify Shell Integration** `[activity: validate]`

  1. Prime: Read shell integration spec `[ref: SDD/Interface Specifications/Shell Integration Protocol]`; read gotcha on ZDOTDIR `[ref: SDD/Gotchas #2]`
  2. Test: Open Kitty and run `echo $KITTY_SHELL_INTEGRATION` — expect non-empty output (e.g. `enabled`)
  3. Implement: If `$KITTY_SHELL_INTEGRATION` is empty:
     - Verify `shell_integration enabled` is in `kitty.conf`
     - Check if `ZDOTDIR` is set to a custom path; if yes, manually source kitty integration:
       ```zsh
       # Add to ~/.zshrc (or $ZDOTDIR/.zshrc)
       if test -n "$KITTY_INSTALLATION_DIR"; then
         export KITTY_SHELL_INTEGRATION="enabled"
         autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
         kitty-integration
         unfunction kitty-integration
       fi
       ```
     - Restart Kitty; re-verify
  4. Validate: `echo $KITTY_SHELL_INTEGRATION` returns `enabled`; navigate to a subdirectory; open overlay with `Cmd+F`; confirm overlay opens in the same directory
  5. Success:
     - [ ] `$KITTY_SHELL_INTEGRATION` is non-empty `[ref: SDD/Interface Specifications/Shell Integration]`
     - [ ] New panes inherit CWD of focused pane `[ref: PRD/AC-ShellInt-1]`
     - [ ] Overlay opens in same CWD as focused pane `[ref: SDD/Overlay Design Walkthrough]`

---

### Phase 5: Keybinding Cheatsheet

Delivers `KEYBINDINGS.md` — the human-readable migration reference with iTerm2/Zellij cross-mapping.

- [ ] **T5.1 Create `KEYBINDINGS.md`** `[activity: build-feature]` `[parallel: true]`

  *(Can run in parallel with Phase 4)*

  1. Prime: Review full keybinding spec `[ref: SDD/Interface Specifications/keybindings.conf]`; review iTerm2→Kitty mapping from research (UX researcher output)
  2. Test: N/A — documentation artifact; validate by reading it cold and confirming every shortcut in T3.2 is present
  3. Implement: Create `~/.config/kitty/KEYBINDINGS.md` with the following content:

     ```markdown
     # Kitty Keybindings Reference

     > Migration guide for iTerm2 and Zellij users.

     ## Pane (Window) Management

     | Action | Kitty | iTerm2 equiv | Zellij equiv |
     |--------|-------|--------------|--------------|
     | Split right (vsplit) | `Cmd+D` | `Cmd+D` | `Ctrl+P r` |
     | Split below (hsplit) | `Cmd+Shift+D` | `Cmd+Shift+D` | `Ctrl+P d` |
     | Close pane | `Cmd+W` | `Cmd+W` | `Ctrl+P x` |
     | Navigate left | `Cmd+Left` | `Cmd+Opt+Left` | `Ctrl+P ←` |
     | Navigate right | `Cmd+Right` | `Cmd+Opt+Right` | `Ctrl+P →` |
     | Navigate up | `Cmd+Up` | `Cmd+Opt+Up` | `Ctrl+P ↑` |
     | Navigate down | `Cmd+Down` | `Cmd+Opt+Down` | `Ctrl+P ↓` |

     > **Note**: `Cmd+arrows` navigates panes when neighbors exist; no-ops otherwise.
     > Use `Cmd+Shift+[/]` to switch tabs when only one pane is open.

     ## Tab Management

     | Action | Kitty | iTerm2 equiv |
     |--------|-------|--------------|
     | New tab | `Cmd+T` | `Cmd+T` |
     | Close tab | `Cmd+Shift+W` | `Cmd+W` |
     | Next tab | `Cmd+Shift+]` | `Cmd+Shift+]` |
     | Previous tab | `Cmd+Shift+[` | `Cmd+Shift+[` |
     | Jump to tab 1-9 | `Cmd+1` through `Cmd+9` | `Cmd+1` through `Cmd+9` |

     ## Layouts

     | Action | Kitty |
     |--------|-------|
     | Cycle layout | `Cmd+L` |
     | Toggle zoom (stack) | `Cmd+Shift+F` |

     **Layout cycle order**: `tall` → `fat` → `grid` → `stack` → (repeat)

     | Layout | Description |
     |--------|-------------|
     | `tall` | Main pane left (60%), others stack right — best for editor + aux |
     | `fat` | Main pane top, others stack below — wide monitor with logs |
     | `grid` | All panes equal size — comparing multiple outputs |
     | `stack` | Single pane visible (focus mode) — distraction-free |

     ## Floating / Overlay

     | Action | Kitty | Zellij equiv |
     |--------|-------|--------------|
     | Open overlay shell | `Cmd+F` | `Ctrl+P w` (floating) |
     | Close overlay | `Ctrl+D` / `exit` | `Ctrl+P w` (toggle) |
     | Zoom current pane | `Cmd+Shift+F` | `Ctrl+P f` (fullscreen) |

     ## OS Windows & Misc

     | Action | Kitty | iTerm2 equiv |
     |--------|-------|--------------|
     | New OS window | `Cmd+N` | `Cmd+N` |
     | Open scrollback | `Cmd+Shift+H` | `Cmd+Shift+B` |
     | Open URL hints | `Cmd+E` | _(no equiv)_ |

     ## Quick Reload

     | Action | How |
     |--------|-----|
     | Reload config | `Ctrl+Shift+F5` |
     | Debug config | `kitty --debug-config` in shell |
     ```

  4. Validate: Read the cheatsheet cold — every shortcut from T3.2 is documented; no undocumented bindings; cross-references are correct
  5. Success:
     - [ ] All 18 bindings from T3.2 table are documented `[ref: PRD/Feature 8]`
     - [ ] iTerm2 equivalents present for all pane/tab actions `[ref: PRD/AC-KB-2]`
     - [ ] Zellij equivalents present for pane actions `[ref: PRD/AC-KB-3]`
     - [ ] Note about `Cmd+arrows` no-op behavior is included `[ref: SDD/ADR-3]`

---

### Phase 6: End-to-End Validation

Full system validation — all PRD acceptance criteria verified against the live Kitty configuration.

- [ ] **T6.1 Theme E2E Validation** `[activity: e2e-test]`

  Verify the complete theme and font story:

  - [ ] Open fresh Kitty window — background is `#1a1b26` (dark navy, not black)
  - [ ] Open LazyVim: `nvim` — no visible color seam between terminal bg and editor bg `[ref: PRD/AC-Theme-1]`
  - [ ] Run `ls --color` — filenames, directories, symlinks appear in Tokyonight palette colors `[ref: PRD/AC-Theme-2]`
  - [ ] Run `lazygit` (or any tool with colored UI) — colors are Tokyonight, not iTerm2 defaults `[ref: PRD/AC-Theme-2]`
  - [ ] Check LazyVim status line: Nerd Font icons (file type, git branch, LSP) render without □ tofu `[ref: PRD/AC-Font-2]`
  - [ ] Check cursor is visible in `#c0caf5` against the dark background `[ref: PRD/AC-Theme-4]`

- [ ] **T6.2 Pane & Layout E2E Validation** `[activity: e2e-test]`

  Verify the complete pane workflow:

  - [ ] `Cmd+D` twice → three panes side-by-side (vsplit) `[ref: PRD/AC-Pane-1]`
  - [ ] `Cmd+Shift+D` → horizontal split below `[ref: PRD/AC-Pane-2]`
  - [ ] `Cmd+arrows` navigate between all panes `[ref: PRD/AC-Nav-1]`
  - [ ] `Cmd+W` closes a pane; remaining panes resize to fill space `[ref: PRD/AC-Pane-3]`
  - [ ] `Cmd+L` cycles through tall → fat → grid → stack → tall `[ref: PRD/AC-Layout-1]`
  - [ ] `Cmd+Shift+F` zooms to single pane (stack); pressing again restores `[ref: PRD/Feature 5]`

- [ ] **T6.3 Overlay E2E Validation** `[activity: e2e-test]`

  Verify the floating pane (overlay) behavior:

  - [ ] With 3 panes open, press `Cmd+F` → overlay appears centered on OS window `[ref: PRD/AC-Overlay-1]`
  - [ ] Run `pwd` in overlay → confirms CWD matches focused pane's directory `[ref: PRD/AC-ShellInt-1]`
  - [ ] Run `git log --oneline` in overlay → output scrolls normally `[ref: PRD/AC-Overlay-3]`
  - [ ] Press `Ctrl+D` → overlay closes; background panes are unchanged `[ref: PRD/AC-Overlay-4]`
  - [ ] Verify background pane processes continued running during overlay (e.g. `watch date` output updated) `[ref: PRD/AC-Overlay-3]`

- [ ] **T6.4 Tab E2E Validation** `[activity: e2e-test]`

  - [ ] `Cmd+T` creates new tab `[ref: PRD/AC-Tab-1]`
  - [ ] `Cmd+1` through `Cmd+9` jump to correct tabs `[ref: PRD/AC-Tab-3]`
  - [ ] `Cmd+Shift+]` and `Cmd+Shift+[` cycle tabs `[ref: PRD/AC-Tab-2]`
  - [ ] `Cmd+Shift+W` closes tab without closing OS window `[ref: PRD/AC-Tab-4]`
  - [ ] Tab bar shows powerline style with Tokyonight active/inactive colors `[ref: PRD/Feature 5]`

- [ ] **T6.5 Specification Compliance** `[activity: business-acceptance]`

  Final compliance check against PRD:

  | PRD Requirement | Implemented | Verified |
  |----------------|-------------|----------|
  | Tokyonight Night theme | T2.1 | T6.1 |
  | RobotoMono Nerd Font Mono 16pt | T1.2 | T6.1 |
  | Vertical split (`Cmd+D`) | T3.1 | T6.2 |
  | Horizontal split (`Cmd+Shift+D`) | T3.1 | T6.2 |
  | Pane navigation (`Cmd+arrows`) | T3.1 | T6.2 |
  | Layout cycling (`Cmd+L`) | T3.1 | T6.2 |
  | Overlay floating pane (`Cmd+F`) | T3.1 | T6.3 |
  | Tab management | T3.1 | T6.4 |
  | Keybinding cheatsheet | T5.1 | T5.1 |
  | Shell integration + CWD inheritance | T4.1 | T6.3 |
  | No audio/visual bells | T1.2 | implicit |
  | Zellij dropped (no dependency) | ADR-5 | config review |

---

## Plan Verification

| Criterion | Status |
|-----------|--------|
| A developer can follow this plan without additional clarification | ✅ |
| Every task produces a verifiable deliverable | ✅ |
| All PRD acceptance criteria map to specific tasks | ✅ |
| All SDD components have implementation tasks | ✅ |
| Dependencies are explicit with no circular references | ✅ |
| Parallel opportunities are marked with `[parallel: true]` | ✅ (T5.1) |
| Each task has specification references `[ref: ...]` | ✅ |
| Project commands in Context Priming are accurate | ✅ |

---

## Dependency Graph

```
T1.1 (font verify)
  └── T1.2 (kitty.conf)
        ├── T2.1 (theme.conf)
        │     └── T2.2 (theme validate)
        │           └── T3.1 (keybindings.conf)
        │                 └── T3.2 (binding verify)
        │                       └── T4.1 (shell integration)
        │                             └── T6.1 → T6.2 → T6.3 → T6.4 → T6.5
        └── T5.1 (KEYBINDINGS.md) [parallel — can start after T3.1]
```

**Critical path**: T1.1 → T1.2 → T2.1 → T3.1 → T3.2 → T4.1 → T6.x

**Parallel opportunity**: T5.1 (cheatsheet) can be written any time after T3.1 is complete and can run alongside T4.1.
