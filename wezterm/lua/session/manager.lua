-- Session manager - CRUD operations for named sessions
local wezterm = require("wezterm")
local state = require("lua.session.state")

local M = {}

local function is_deleted_session(name)
	local deleted = wezterm.GLOBAL.deleted_sessions or {}
	return deleted[name] == true
end

local function clear_deleted_marker(name)
	local deleted = wezterm.GLOBAL.deleted_sessions
	if deleted then
		deleted[name] = nil
	end
end

-- Create a new session or switch to existing one (idempotent)
-- @param name: session name
-- @return: true on success, nil + error message on failure
function M.create_session(name)
	-- Validate name
	if not name or name == "" then
		return nil, "Session name cannot be empty"
	end

	if not name:match("^[%w%-_]+$") then
		return nil, "Session name must contain only alphanumeric characters, dashes, and underscores"
	end

	-- Check if session already exists (idempotent behavior)
	local sessions = M.list_sessions()
	for _, session in ipairs(sessions) do
		if session.name == name then
			-- Session exists, switch to it
			wezterm.log_info("Session '" .. name .. "' already exists, switching to it")
			return M.switch_session(name)
		end
	end

	-- Auto-save current workspace before creating new one
	state.save_current_workspace()

	-- Create new workspace
	local tab, pane, window = wezterm.mux.spawn_window({
		workspace = name,
		cwd = wezterm.home_dir,
	})

	if not window then
		return nil, "Failed to create workspace"
	end

	clear_deleted_marker(name)
	wezterm.log_info("Created new session: " .. name)
	return true
end

-- List all sessions (active workspaces + saved JSON sessions)
-- @return: array of { name, active, last_saved } sorted by last_saved descending
function M.list_sessions()
	local sessions = {}
	local seen = {}

	-- Enumerate active workspaces (skip "default" and deleted sessions)
	for _, window in ipairs(wezterm.mux.all_windows()) do
		local workspace = window:get_workspace()
		if workspace and workspace ~= "default" and not is_deleted_session(workspace) and not seen[workspace] then
			sessions[#sessions + 1] = {
				name = workspace,
				active = true,
				last_saved = nil,
			}
			seen[workspace] = #sessions
		end
	end

	-- Enumerate JSON files
	local sessions_dir = state.sessions_dir
	local ls_handle = io.popen('ls -1 "' .. sessions_dir .. '"/*.json 2>/dev/null')
	if ls_handle then
		for filename in ls_handle:lines() do
			local basename = filename:match("([^/]+)%.json$")
			if basename and basename ~= "default" and not is_deleted_session(basename) then
				local layout = state.load_workspace(basename)
				if seen[basename] then
					-- Active workspace with JSON - update last_saved
					sessions[seen[basename]].last_saved = layout and layout.last_saved
				else
					-- Saved-only session
					sessions[#sessions + 1] = {
						name = basename,
						active = false,
						last_saved = layout and layout.last_saved,
					}
				end
			end
		end
		ls_handle:close()
	end

	-- Sort by last_saved descending (most recent first)
	table.sort(sessions, function(a, b)
		-- Both have timestamps - compare numerically
		if a.last_saved and b.last_saved then
			return a.last_saved > b.last_saved
		end
		-- Only a has timestamp - a comes first
		if a.last_saved then
			return true
		end
		-- Only b has timestamp - b comes first
		if b.last_saved then
			return false
		end
		-- Neither has timestamp - sort alphabetically
		return a.name < b.name
	end)

	return sessions
end

-- Switch to an existing session
-- @param name: session name
-- @return: true on success, nil + error message on failure
function M.switch_session(name)
	-- Auto-save current workspace before switching
	state.save_current_workspace()

	-- Check if workspace already running
	local exists = false
	for _, window in ipairs(wezterm.mux.all_windows()) do
		if window:get_workspace() == name then
			exists = true
			break
		end
	end

	-- If not running, check if JSON exists
	if not exists then
		local layout = state.load_workspace(name)
		if not layout then
			return nil, "Session '" .. name .. "' not found"
		end
	end

	-- Switch to workspace by spawning a window in it
	-- This is the cross-context method that works without window:perform_action
	local tab, pane, window = wezterm.mux.spawn_window({
		workspace = name,
		cwd = wezterm.home_dir,
	})

	if not window then
		return nil, "Failed to switch to workspace"
	end

	clear_deleted_marker(name)
	wezterm.log_info("Switched to session: " .. name)
	return true
end

-- Delete a session (remove JSON + close workspace panes)
-- @param name: session name
-- @return: true on success, nil + error message on failure
function M.delete_session(name)
	-- Protect default workspace
	if name == "default" then
		return nil, "Cannot delete default workspace"
	end

	-- Validate session exists
	local sessions = M.list_sessions()
	local found = false
	for _, session in ipairs(sessions) do
		if session.name == name then
			found = true
			break
		end
	end

	if not found then
		return nil, "Session '" .. name .. "' not found"
	end

	-- If deleting active session, switch to another session first
	local current = wezterm.mux.get_active_workspace()
	if name == current then
		-- Find an alternative session to switch to
		local target = nil
		for _, session in ipairs(sessions) do
			if session.name ~= name then
				target = session.name
				break
			end
		end

		-- Fallback to default if no other sessions exist
		if not target then
			target = "default"
		end

		-- Switch away from the session being deleted
		local ok, err = M.switch_session(target)
		if not ok then
			wezterm.log_warn("Failed to switch away from deleted session: " .. (err or "unknown error"))
		end
	end

	-- Remove JSON file (may not exist if session was never saved)
	local sanitized = name:gsub("[^%w%-_]", "_")
	local json_path = state.sessions_dir .. "/" .. sanitized .. ".json"
	os.remove(json_path) -- silent if file doesn't exist

	-- Mark as deleted so auto-save skips this workspace
	wezterm.GLOBAL.deleted_sessions = wezterm.GLOBAL.deleted_sessions or {}
	wezterm.GLOBAL.deleted_sessions[name] = true

	-- Close all workspace panes using CLI kill-pane (exit\n is unreliable)
	for _, window in ipairs(wezterm.mux.all_windows()) do
		if window:get_workspace() == name then
			for _, tab in ipairs(window:tabs()) do
				for _, pane in ipairs(tab:panes()) do
					local pane_id = tostring(pane:pane_id())
					wezterm.run_child_process({ "wezterm", "cli", "kill-pane", "--pane-id", pane_id })
				end
			end
		end
	end

	wezterm.log_info("Deleted session: " .. name)
	return true
end

-- Allowlist of processes that can be restored via send_text
local RESTORABLE_PROCESSES = {
	nvim = "nvim",
	claude = "claude",
	npm = "npm run dev",
	node = "node",
}
-- Shells (zsh, bash, fish) are NOT in this table -- they spawn by default

-- Smart attach: switch to running workspace or restore from JSON
-- @param name: session name
-- @return: true on success, nil + error message on failure
function M.attach_session(name)
	-- Validate name
	if not name or name == "" then
		return nil, "Session name cannot be empty"
	end

	if not name:match("^[%w%-_]+$") then
		return nil, "Session name must contain only alphanumeric characters, dashes, and underscores"
	end

	-- Check if workspace is already running
	for _, window in ipairs(wezterm.mux.all_windows()) do
		if window:get_workspace() == name then
			-- Running workspace - activate a pane in it to focus the workspace
			-- Find first pane in this workspace
			for _, tab in ipairs(window:tabs()) do
				local panes = tab:panes()
				if panes and #panes > 0 then
					-- Activate this pane to bring workspace into focus
					local pane_id = panes[1]:pane_id()
					local args = { "wezterm", "cli", "activate-pane", "--pane-id", tostring(pane_id) }
					wezterm.run_child_process(args)
					wezterm.log_info("Attached to running session: " .. name)
					return true
				end
			end
			-- Fallback: if we couldn't find a pane, use the old switch method
			return M.switch_session(name)
		end
	end

	-- Not running - check if JSON exists
	local layout = state.load_workspace(name)
	if not layout then
		return nil, "Session '" .. name .. "' not found"
	end

	-- JSON exists - restore it
	return M.restore_session(name)
end

-- Restore session from JSON (full layout reconstruction)
-- @param name: session name
-- @return: true on success, nil + error message on failure
function M.restore_session(name)
	-- Load layout
	local layout = state.load_workspace(name)
	if not layout then
		return nil, "Session '" .. name .. "' not found"
	end

	-- Auto-save current workspace before restoring
	state.save_current_workspace()

	-- Get first tab's first pane CWD for initial spawn
	local first_cwd = wezterm.home_dir
	if layout.tabs and #layout.tabs > 0 and layout.tabs[1].panes and #layout.tabs[1].panes > 0 then
		first_cwd = layout.tabs[1].panes[1].cwd or wezterm.home_dir
	end

	-- Spawn new workspace
	local tab, pane, window = wezterm.mux.spawn_window({
		workspace = name,
		cwd = first_cwd,
	})

	if not window then
		return nil, "Failed to create workspace window"
	end

	clear_deleted_marker(name)
	-- Restore layout
	M._restore_layout(layout, window, pane)

	wezterm.log_info("Restored session: " .. name)
	return true
end

-- Internal: Restore layout structure (tabs and initial panes)
-- @param layout: parsed JSON layout table
-- @param window: MuxWindow object
-- @param initial_pane: MuxPane from spawn_window
function M._restore_layout(layout, window, initial_pane)
	if not layout.tabs or #layout.tabs == 0 then
		return
	end

	-- Track if we've tried MuxPane:split() yet
	local split_method = nil

	for tab_idx, tab_data in ipairs(layout.tabs) do
		local target_tab = nil
		local first_pane_in_tab = nil

		if tab_idx == 1 then
			-- Reuse existing tab and initial pane
			target_tab = window:active_tab()
			first_pane_in_tab = initial_pane
		else
			-- Spawn new tab
			local first_pane_cwd = wezterm.home_dir
			if tab_data.panes and #tab_data.panes > 0 then
				first_pane_cwd = tab_data.panes[1].cwd or wezterm.home_dir
			end

			local new_tab, new_pane = window:spawn_tab({ cwd = first_pane_cwd })
			if new_tab and new_pane then
				target_tab = new_tab
				first_pane_in_tab = new_pane
			else
				wezterm.log_warn("Failed to spawn tab " .. tab_idx .. ", skipping")
			end
		end

		-- Set tab title
		if target_tab and tab_data.title and tab_data.title ~= "" then
			target_tab:set_title(tab_data.title)
		end

		-- Restore panes in this tab
		if target_tab and first_pane_in_tab then
			split_method = M._restore_tab_panes(tab_data, first_pane_in_tab, split_method)
		end
	end
end

-- Internal: Restore panes within a tab
-- @param tab_data: tab table from layout JSON
-- @param first_pane: MuxPane to use as split anchor
-- @param split_method: "lua"|"cli"|nil (auto-detect on first call)
-- @return: split_method used (for propagation to next tabs)
function M._restore_tab_panes(tab_data, first_pane, split_method)
	if not tab_data.panes or #tab_data.panes == 0 then
		return split_method
	end

	local panes = tab_data.panes

	-- Configure first pane
	M._configure_pane(first_pane, panes[1])

	-- Restore remaining panes via splits
	for i = 2, #panes do
		local pane_data = panes[i]
		local prev_pane_data = panes[i - 1]

		-- Infer split direction from geometry
		local direction = "Bottom" -- default
		if pane_data.left and prev_pane_data.left and prev_pane_data.width then
			local prev_right_edge = prev_pane_data.left + (prev_pane_data.width / 2)
			if pane_data.left > prev_right_edge then
				direction = "Right"
			end
		end

		-- Get CWD
		local cwd = pane_data.cwd or wezterm.home_dir

		-- Try to split
		local new_pane = nil
		local split_opts = { direction = direction, cwd = cwd }

		-- Auto-detect split method on first attempt
		if split_method == nil then
			-- Try Lua MuxPane:split() method first
			local lua_ok, lua_result = pcall(function()
				return first_pane:split(split_opts)
			end)

			if lua_ok and lua_result then
				split_method = "lua"
				new_pane = lua_result
				wezterm.log_info("Using MuxPane:split() Lua method for pane splits")
			else
				-- Lua method not available, fall back to CLI
				split_method = "cli"
				wezterm.log_info("MuxPane:split() not available, using CLI fallback")
			end
		end

		-- Execute split using detected method
		if split_method == "lua" and not new_pane then
			local ok, result = pcall(function()
				return first_pane:split(split_opts)
			end)
			if ok and result then
				new_pane = result
			else
				wezterm.log_warn("Failed to split pane " .. i .. " (Lua method): " .. tostring(result))
			end
		elseif split_method == "cli" then
			-- CLI fallback using wezterm cli split-pane
			local pane_id = tostring(first_pane:pane_id())
			local cli_args = {
				"wezterm",
				"cli",
				"split-pane",
				"--pane-id",
				pane_id,
				"--" .. (direction == "Right" and "right" or "bottom"),
				"--cwd",
				cwd,
			}

			local ok, stdout, stderr = wezterm.run_child_process(cli_args)
			if ok then
				-- CLI returns pane ID as text, but we can't easily get MuxPane from ID
				-- Just log success and continue without new_pane reference
				wezterm.log_info("Split pane " .. i .. " via CLI")
			else
				wezterm.log_warn("Failed to split pane " .. i .. " (CLI method): " .. tostring(stderr))
			end
		end

		-- Configure new pane if we have a reference to it
		if new_pane then
			M._configure_pane(new_pane, pane_data)
		end

		-- Warn about degraded accuracy for complex layouts
		if i > 4 then
			wezterm.log_warn("Restoring pane " .. i .. " - complex layouts may have reduced accuracy")
		end
	end

	return split_method
end

-- Internal: Configure a pane (send process launch command)
-- @param pane: MuxPane object
-- @param pane_data: pane table from layout JSON
function M._configure_pane(pane, pane_data)
	-- No process or nil process - shell spawns by default
	if not pane_data.process then
		return
	end

	local process = pane_data.process

	-- Shell processes spawn automatically, no action needed
	if process == "zsh" or process == "bash" or process == "fish" or process == "sh" then
		return
	end

	-- Check if process is restorable
	local command = RESTORABLE_PROCESSES[process]
	if command then
		pane:send_text(command .. "\n")
	else
		-- Unknown process, log and skip
		wezterm.log_info("Skipping non-restorable process: " .. process)
	end
end

return M
