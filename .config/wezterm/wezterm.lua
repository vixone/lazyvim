-- WezTerm Configuration
-- Migrated from Kitty terminal configuration
-- Based on ~/.config/kitty/kitty.conf, keybindings.conf, theme.conf

local wezterm = require("wezterm")
local act = wezterm.action
local smart_splits = wezterm.plugin.require("https://github.com/mrjones2014/smart-splits.nvim")
local config = {}

if wezterm.config_builder then
	config = wezterm.config_builder()
end

-- ─── THEME MODE ───────────────────────────────────────────────────
-- Reads ~/.config/wezterm/theme-mode ("dark" or "light")
-- Toggle with: toggle-theme (shell) or CMD+SHIFT+T (keybinding)
local theme_file = wezterm.config_dir .. "/theme-mode"

local function read_theme_mode()
	local f = io.open(theme_file, "r")
	if not f then
		return "dark"
	end
	local mode = f:read("*l")
	f:close()
	return (mode and mode:match("light")) and "light" or "dark"
end

local mode = read_theme_mode()

-- Catppuccin Mocha (dark) / Latte (light)
local themes = {
	dark = {
		colors = {
			foreground = "#cdd6f4", -- Text
			background = "#1e1e2e", -- Base
			cursor_bg = "#f5e0dc", -- Rosewater
			cursor_fg = "#1e1e2e", -- Base
			cursor_border = "#f5e0dc", -- Rosewater
			selection_bg = "#585b70", -- Surface2
			selection_fg = "#cdd6f4", -- Text
			tab_bar = {
				background = "#181825", -- Mantle
				active_tab = { bg_color = "#cba6f7", fg_color = "#181825", intensity = "Bold" }, -- Mauve
				inactive_tab = { bg_color = "#1e1e2e", fg_color = "#6c7086" }, -- Base, Overlay0
				inactive_tab_hover = { bg_color = "#313244", fg_color = "#cdd6f4" }, -- Surface0, Text
				new_tab = { bg_color = "#1e1e2e", fg_color = "#6c7086" },
				new_tab_hover = { bg_color = "#313244", fg_color = "#cdd6f4" },
			},
			ansi = {
				"#45475a", -- Surface1 (black)
				"#f38ba8", -- Red
				"#a6e3a1", -- Green
				"#f9e2af", -- Yellow
				"#89b4fa", -- Blue
				"#f5c2e7", -- Pink (magenta)
				"#94e2d5", -- Teal (cyan)
				"#bac2de", -- Subtext1 (white)
			},
			brights = {
				"#585b70", -- Surface2 (bright black)
				"#f38ba8", -- Red
				"#a6e3a1", -- Green
				"#f9e2af", -- Yellow
				"#89b4fa", -- Blue
				"#f5c2e7", -- Pink
				"#94e2d5", -- Teal
				"#a6adc8", -- Subtext0 (bright white)
			},
		},
		hints = { key = "#89b4fa", label = "#6c7086", sep = "#45475a" }, -- Blue, Overlay0, Surface1
	},
	light = {
		colors = {
			foreground = "#4c4f69", -- Text
			background = "#eff1f5", -- Base
			cursor_bg = "#dc8a78", -- Rosewater
			cursor_fg = "#eff1f5", -- Base
			cursor_border = "#dc8a78", -- Rosewater
			selection_bg = "#acb0be", -- Surface2
			selection_fg = "#4c4f69", -- Text
			tab_bar = {
				background = "#e6e9ef", -- Mantle
				active_tab = { bg_color = "#8839ef", fg_color = "#e6e9ef", intensity = "Bold" }, -- Mauve
				inactive_tab = { bg_color = "#eff1f5", fg_color = "#9ca0b0" }, -- Base, Overlay0
				inactive_tab_hover = { bg_color = "#ccd0da", fg_color = "#4c4f69" }, -- Surface0, Text
				new_tab = { bg_color = "#eff1f5", fg_color = "#9ca0b0" },
				new_tab_hover = { bg_color = "#ccd0da", fg_color = "#4c4f69" },
			},
			ansi = {
				"#bcc0cc", -- Surface1 (black)
				"#d20f39", -- Red
				"#40a02b", -- Green
				"#df8e1d", -- Yellow
				"#1e66f5", -- Blue
				"#ea76cb", -- Pink (magenta)
				"#179299", -- Teal (cyan)
				"#5c5f77", -- Subtext1 (white)
			},
			brights = {
				"#acb0be", -- Surface2 (bright black)
				"#d20f39", -- Red
				"#40a02b", -- Green
				"#df8e1d", -- Yellow
				"#1e66f5", -- Blue
				"#ea76cb", -- Pink
				"#179299", -- Teal
				"#6c6f85", -- Subtext0 (bright white)
			},
		},
		hints = { key = "#1e66f5", label = "#9ca0b0", sep = "#bcc0cc" }, -- Blue, Overlay0, Surface1
	},
}

local theme = themes[mode]

-- ─── FONTS ─────────────────────────────────────────────────────────
config.font = wezterm.font("RobotoMono Nerd Font Mono")
config.font_size = 16.0

-- ─── APPEARANCE ────────────────────────────────────────────────────
config.colors = theme.colors

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

config.window_decorations = "RESIZE"
config.enable_scroll_bar = false
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = false
config.tab_bar_at_bottom = false

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
		key = "t",
		mods = "CMD",
		action = act.SpawnTab("CurrentPaneDomain"),
	},

	-- Switch to specific tab (cmd+1 through cmd+9)
	{ key = "1", mods = "CMD", action = act.ActivateTab(0) },
	{ key = "2", mods = "CMD", action = act.ActivateTab(1) },
	{ key = "3", mods = "CMD", action = act.ActivateTab(2) },
	{ key = "4", mods = "CMD", action = act.ActivateTab(3) },
	{ key = "5", mods = "CMD", action = act.ActivateTab(4) },
	{ key = "6", mods = "CMD", action = act.ActivateTab(5) },
	{ key = "7", mods = "CMD", action = act.ActivateTab(6) },
	{ key = "8", mods = "CMD", action = act.ActivateTab(7) },
	{ key = "9", mods = "CMD", action = act.ActivateTab(8) },

	-- Previous/Next tab (opt+h / opt+l)
	{
		key = "h",
		mods = "OPT",
		action = act.ActivateTabRelative(-1),
	},
	{
		key = "l",
		mods = "OPT",
		action = act.ActivateTabRelative(1),
	},

	-- Clear terminal (ctrl+cmd+l) since ctrl+l is used by smart-splits
	{
		key = "l",
		mods = "CTRL|CMD",
		action = act.ClearScrollback("ScrollbackAndViewport"),
	},

	-- ─── PANE (SPLIT) MANAGEMENT ─────────────────────────────────────
	-- Split vertical (cmd+d)
	{
		key = "d",
		mods = "CMD",
		action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }),
	},

	-- Close pane (cmd+w)
	{
		key = "w",
		mods = "CMD",
		action = act.CloseCurrentPane({ confirm = false }),
	},

	-- Close tab (cmd+shift+w)
	{
		key = "w",
		mods = "CMD|SHIFT",
		action = act.CloseCurrentTab({ confirm = false }),
	},

	-- ─── PANE NAVIGATION (ctrl+hjkl) ─────────────────────────────────
	-- Handled by smart-splits.nvim plugin (seamless vim/wezterm navigation)

	-- ─── PANE RESIZE (alt+arrow keys) ────────────────────────────────
	{
		key = "LeftArrow",
		mods = "ALT",
		action = act.AdjustPaneSize({ "Left", 5 }),
	},
	{
		key = "RightArrow",
		mods = "ALT",
		action = act.AdjustPaneSize({ "Right", 5 }),
	},
	{
		key = "UpArrow",
		mods = "ALT",
		action = act.AdjustPaneSize({ "Up", 5 }),
	},
	{
		key = "DownArrow",
		mods = "ALT",
		action = act.AdjustPaneSize({ "Down", 5 }),
	},

	-- ─── CLIPBOARD ───────────────────────────────────────────────────
	-- Paste screenshot from clipboard (ctrl+period)
	-- Extracts image from clipboard and saves to /tmp/screenshot_TIMESTAMP.png
	{
		key = ".",
		mods = "CTRL",
		action = wezterm.action_callback(function(window, pane)
			local success, stdout, stderr = wezterm.run_child_process({
				"osascript",
				"-e",
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
        ]],
			})

			if success and stdout ~= "" then
				local filepath = stdout:gsub("%s+$", "")
				pane:send_text(filepath)
			end
		end),
	},

	-- ─── CONFIG RELOAD (cmd+ctrl+,) ──────────────────────────────────
	{
		key = ",",
		mods = "CMD|CTRL",
		action = act.ReloadConfiguration,
	},

	-- ─── ZOOM PANE ───────────────────────────────────────────────────
	{
		key = "z",
		mods = "CMD",
		action = act.TogglePaneZoomState,
	},

	-- ─── TAB RENAME (ctrl+cmd+r) ─────────────────────────────────────
	{
		key = "r",
		mods = "CTRL|CMD",
		action = act.PromptInputLine({
			description = "Enter new name for tab",
			action = wezterm.action_callback(function(window, pane, line)
				if line then
					window:active_tab():set_title(line)
				end
			end),
		}),
	},

	-- ─── SPLIT HORIZONTAL (cmd+f) ───────────────────────────────────
	{
		key = "f",
		mods = "CMD",
		action = act.SplitVertical({ domain = "CurrentPaneDomain" }),
	},

	-- ─── FULLSCREEN TOGGLE (cmd+enter) ──────────────────────────────
	{
		key = "Enter",
		mods = "CMD",
		action = act.ToggleFullScreen,
	},

	-- ─── DAILY NOTES (cmd+shift+n) ──────────────────────────────────
	-- Opens today's daily note in a new tab via nvim + obsidian vault
	-- Uses login shell to ensure full PATH (homebrew, etc.) is available
	{
		key = "n",
		mods = "CMD|SHIFT",
		action = act.SplitVertical({
			args = { "/bin/zsh", "-l", "-c", os.getenv("HOME") .. "/obsidian-notes/open-daily-note.sh" },
		}),
	},

	-- ─── UNCHECKED IDEAS (cmd+shift+m) ───────────────────────────────
	-- Opens aggregated unchecked tasks from all daily notes
	-- Auto-refreshes the list before opening
	{
		key = "m",
		mods = "CMD|SHIFT",
		action = act.SplitVertical({
			args = { "/bin/zsh", "-l", "-c", os.getenv("HOME") .. "/obsidian-notes/open-unchecked-ideas.sh" },
		}),
	},

	-- ─── THEME TOGGLE (cmd+shift+t) ─────────────────────────────────
	-- Toggles dark/light mode for WezTerm (+ nvim picks it up via file watcher)
	{
		key = "t",
		mods = "CMD|SHIFT",
		action = wezterm.action_callback(function(window, pane)
			local f = io.open(theme_file, "r")
			local current = f and f:read("*l") or "dark"
			if f then
				f:close()
			end

			local new_mode = (current and current:match("light")) and "dark" or "light"

			f = io.open(theme_file, "w")
			if f then
				f:write(new_mode .. "\n")
				f:close()
			end

			-- Touch config file to trigger WezTerm reload
			wezterm.run_child_process({ "/usr/bin/touch", wezterm.config_file })
		end),
	},
}

-- ─── COPY ON SELECT ────────────────────────────────────────────────
config.selection_word_boundary = " \t\n{}[]()\"'`"

-- Automatically copy selection to clipboard (like kitty's copy_on_select)
-- + Zellij-style shortcut hints in the tab bar
wezterm.on("update-status", function(window, pane)
	-- Copy on select
	local sel = window:get_selection_text_for_pane(pane)
	if sel and sel ~= "" then
		window:copy_to_clipboard(sel, "Clipboard")
	end

	-- Shortcut hints (Zellij-style)
	local hints = {
		{ key = "^⌘R", label = "RenameTab" },
		{ key = "⇧⌘N", label = "DailyNote↓" },
		{ key = "⇧⌘M", label = "Ideas↓" },
		{ key = "⇧⌘T", label = "Theme" },
	}

	local h = theme.hints
	local elements = {}
	for i, hint in ipairs(hints) do
		if i > 1 then
			table.insert(elements, { Foreground = { Color = h.sep } })
			table.insert(elements, { Text = " │ " })
		end
		table.insert(elements, { Foreground = { Color = h.key } })
		table.insert(elements, { Text = hint.key })
		table.insert(elements, { Foreground = { Color = h.label } })
		table.insert(elements, { Text = " " .. hint.label })
	end

	window:set_right_status(wezterm.format(elements))
end)

-- ─── SMART SPLITS (seamless vim/wezterm pane navigation) ─────────
-- Ctrl+hjkl navigates between both neovim splits AND wezterm panes
smart_splits.apply_to_config(config, {
	direction_keys = { "h", "j", "k", "l" },
	modifiers = {
		move = "CTRL", -- ctrl+hjkl to move between panes/splits
		resize = "CTRL|SHIFT", -- ctrl+shift+hjkl to resize (avoids conflict with opt+hl tab switching)
	},
})

return config
