-- WezTerm Configuration
-- Migrated from Kitty terminal configuration
-- Based on ~/.config/kitty/kitty.conf, keybindings.conf, theme.conf

local wezterm = require 'wezterm'
local act = wezterm.action
local config = {}

if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- ─── FONTS ─────────────────────────────────────────────────────────
config.font = wezterm.font 'RobotoMono Nerd Font Mono'
config.font_size = 16.0

-- ─── APPEARANCE ────────────────────────────────────────────────────
-- Tokyonight Moon theme (matched to kitty theme.conf)
config.colors = {
  foreground = '#c0caf5',
  background = '#222436',

  cursor_bg = '#c0caf5',
  cursor_fg = '#222436',
  cursor_border = '#c0caf5',

  selection_bg = '#283457',
  selection_fg = '#c0caf5',

  -- Tab bar colors
  tab_bar = {
    background = '#1e2030',
    active_tab = {
      bg_color = '#7aa2f7',
      fg_color = '#222436',
      intensity = 'Bold',
    },
    inactive_tab = {
      bg_color = '#222436',
      fg_color = '#565f89',
    },
    inactive_tab_hover = {
      bg_color = '#414868',
      fg_color = '#c0caf5',
    },
    new_tab = {
      bg_color = '#222436',
      fg_color = '#565f89',
    },
    new_tab_hover = {
      bg_color = '#414868',
      fg_color = '#c0caf5',
    },
  },

  -- ANSI colors (normal)
  ansi = {
    '#15161e', -- black
    '#f7768e', -- red
    '#9ece6a', -- green
    '#e0af68', -- yellow
    '#7aa2f7', -- blue
    '#bb9af7', -- magenta
    '#7dcfff', -- cyan
    '#a9b1d6', -- white
  },

  -- ANSI colors (bright)
  brights = {
    '#414868', -- bright black
    '#f7768e', -- bright red
    '#9ece6a', -- bright green
    '#e0af68', -- bright yellow
    '#7aa2f7', -- bright blue
    '#bb9af7', -- bright magenta
    '#7dcfff', -- bright cyan
    '#c0caf5', -- bright white
  },
}

-- ─── WINDOW ────────────────────────────────────────────────────────
config.window_padding = {
  left = 8,
  right = 8,
  top = 8,
  bottom = 8,
}

-- Transparency settings
config.window_background_opacity = 0.93
config.macos_window_background_blur = 20

config.enable_scroll_bar = false
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = true

-- Tab title formatting (similar to kitty's tab_title_template)
config.tab_max_width = 32

-- ─── SCROLLBACK ────────────────────────────────────────────────────
config.scrollback_lines = 4000

-- ─── BELLS & CURSOR ────────────────────────────────────────────────
config.audible_bell = "Disabled"
config.visual_bell = {
  fade_in_duration_ms = 0,
  fade_out_duration_ms = 0,
}
config.cursor_blink_rate = 0

-- ─── PERFORMANCE ───────────────────────────────────────────────────
config.front_end = "WebGpu"
config.max_fps = 120

-- ─── PANE BORDERS ──────────────────────────────────────────────────
config.inactive_pane_hsb = {
  saturation = 0.9,
  brightness = 0.6,
}

-- ─── KEYBINDINGS ───────────────────────────────────────────────────
config.keys = {
  -- ─── TAB MANAGEMENT ──────────────────────────────────────────────
  -- New tab (cmd+t)
  {
    key = 't',
    mods = 'CMD',
    action = act.SpawnTab 'CurrentPaneDomain',
  },

  -- Switch to specific tab (cmd+1 through cmd+9)
  { key = '1', mods = 'CMD', action = act.ActivateTab(0) },
  { key = '2', mods = 'CMD', action = act.ActivateTab(1) },
  { key = '3', mods = 'CMD', action = act.ActivateTab(2) },
  { key = '4', mods = 'CMD', action = act.ActivateTab(3) },
  { key = '5', mods = 'CMD', action = act.ActivateTab(4) },
  { key = '6', mods = 'CMD', action = act.ActivateTab(5) },
  { key = '7', mods = 'CMD', action = act.ActivateTab(6) },
  { key = '8', mods = 'CMD', action = act.ActivateTab(7) },
  { key = '9', mods = 'CMD', action = act.ActivateTab(8) },

  -- Previous/Next tab (opt+h / opt+l)
  {
    key = 'h',
    mods = 'OPT',
    action = act.ActivateTabRelative(-1),
  },
  {
    key = 'l',
    mods = 'OPT',
    action = act.ActivateTabRelative(1),
  },

  -- ─── PANE (SPLIT) MANAGEMENT ─────────────────────────────────────
  -- Split vertical (cmd+d)
  {
    key = 'd',
    mods = 'CMD',
    action = act.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },

  -- Split horizontal (cmd+shift+d)
  {
    key = 'd',
    mods = 'CMD|SHIFT',
    action = act.SplitVertical { domain = 'CurrentPaneDomain' },
  },

  -- Close pane (cmd+w)
  {
    key = 'w',
    mods = 'CMD',
    action = act.CloseCurrentPane { confirm = false },
  },

  -- Close tab (cmd+shift+w)
  {
    key = 'w',
    mods = 'CMD|SHIFT',
    action = act.CloseCurrentTab { confirm = false },
  },

  -- ─── PANE NAVIGATION (ctrl+hjkl) ─────────────────────────────────
  {
    key = 'h',
    mods = 'CTRL',
    action = act.ActivatePaneDirection 'Left',
  },
  {
    key = 'j',
    mods = 'CTRL',
    action = act.ActivatePaneDirection 'Down',
  },
  {
    key = 'k',
    mods = 'CTRL',
    action = act.ActivatePaneDirection 'Up',
  },
  {
    key = 'l',
    mods = 'CTRL',
    action = act.ActivatePaneDirection 'Right',
  },

  -- ─── PANE RESIZE (alt+arrow keys) ────────────────────────────────
  {
    key = 'LeftArrow',
    mods = 'ALT',
    action = act.AdjustPaneSize { 'Left', 5 },
  },
  {
    key = 'RightArrow',
    mods = 'ALT',
    action = act.AdjustPaneSize { 'Right', 5 },
  },
  {
    key = 'UpArrow',
    mods = 'ALT',
    action = act.AdjustPaneSize { 'Up', 5 },
  },
  {
    key = 'DownArrow',
    mods = 'ALT',
    action = act.AdjustPaneSize { 'Down', 5 },
  },

  -- ─── CLIPBOARD ───────────────────────────────────────────────────
  -- Paste screenshot from clipboard (ctrl+period)
  -- Extracts image from clipboard and saves to /tmp/screenshot_TIMESTAMP.png
  {
    key = '.',
    mods = 'CTRL',
    action = wezterm.action_callback(function(window, pane)
      local success, stdout, stderr = wezterm.run_child_process({
        'osascript',
        '-e',
        [[
          set theFile to "/tmp/screenshot_" & (do shell script "date +%Y%m%d_%H%M%S") & ".png"
          try
            set imgData to the clipboard as «class PNGf»
            set imgFile to open for access theFile with write permission
            write imgData to imgFile
            close access imgFile
            return theFile
          on error
            return ""
          end try
        ]]
      })

      if success and stdout ~= "" then
        local filepath = stdout:gsub("%s+$", "")
        pane:send_text(filepath)
      end
    end),
  },

  -- ─── CONFIG RELOAD (cmd+ctrl+,) ──────────────────────────────────
  {
    key = ',',
    mods = 'CMD|CTRL',
    action = act.ReloadConfiguration,
  },

  -- ─── ZOOM PANE ───────────────────────────────────────────────────
  {
    key = 'z',
    mods = 'CMD',
    action = act.TogglePaneZoomState,
  },

  -- ─── TAB RENAME ──────────────────────────────────────────────────
  {
    key = 'r',
    mods = 'CMD|SHIFT',
    action = act.PromptInputLine {
      description = 'Enter new name for tab',
      action = wezterm.action_callback(function(window, pane, line)
        if line then
          window:active_tab():set_title(line)
        end
      end),
    },
  },

  -- ─── PANE FULLSCREEN ─────────────────────────────────────────────
  {
    key = 'f',
    mods = 'CMD',
    action = act.TogglePaneZoomState,
  },
}

-- ─── COPY ON SELECT ────────────────────────────────────────────────
config.selection_word_boundary = ' \t\n{}[]()"\'`'

-- Automatically copy selection to clipboard (like kitty's copy_on_select)
wezterm.on('update-status', function(window, pane)
  local sel = window:get_selection_text_for_pane(pane)
  if sel and sel ~= "" then
    window:copy_to_clipboard(sel, 'Clipboard')
  end
end)

return config
