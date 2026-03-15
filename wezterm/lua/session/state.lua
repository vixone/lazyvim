-- Layout serialization and workspace state management
local wezterm = require("wezterm")

local M = {}

-- Session data lives OUTSIDE config_dir to avoid triggering WezTerm hot-reload
M.sessions_dir = wezterm.home_dir .. "/.local/state/wezterm/sessions"

-- Convert file:// URI to filesystem path
-- @param uri_obj: Url object from pane:get_current_working_dir() or nil
-- @return: string path or nil
function M.uri_to_path(uri_obj)
	if not uri_obj then
		return nil
	end

	local uri_str = tostring(uri_obj)
	if not uri_str then
		return nil
	end

	-- Platform-specific URI handling
	local target = wezterm.target_triple
	if target:find("windows") then
		-- Windows: file:///C:/path -> C:/path
		return uri_str:gsub("^file:///", "")
	else
		-- macOS/Linux: file:///path or file://hostname/path -> /path
		return uri_str:gsub("^file://[^/]*/", "/")
	end
end

-- Capture current workspace layout
-- @return: Lua table with workspace state
function M.capture_workspace()
	local mux = wezterm.mux
	local active_workspace = mux.get_active_workspace()

	local tabs_data = {}

	-- Iterate all mux windows in the active workspace
	for _, window in ipairs(mux.all_windows()) do
		if window:get_workspace() == active_workspace then
			-- Get active tab ID for comparison (is_active() doesn't exist on MuxTab)
			local active_tab = window:active_tab()
			local active_tab_id = active_tab and active_tab:tab_id()

			-- Iterate tabs in this window
			for _, tab in ipairs(window:tabs()) do
				local panes_data = {}

				-- Get pane layout info
				local panes_with_info = tab:panes_with_info()
				for _, pane_info in ipairs(panes_with_info) do
					local pane = pane_info.pane

					-- Get CWD (nil-safe)
					local cwd_uri = pane:get_current_working_dir()
					local cwd = M.uri_to_path(cwd_uri)

					-- Get foreground process (nil-safe)
					local process = pane:get_foreground_process_name()
					if process then
						-- Extract basename (e.g., /bin/zsh -> zsh)
						process = process:match("([^/]+)$") or process
					end

					table.insert(panes_data, {
						index = pane_info.index,
						is_active = pane_info.is_active,
						cwd = cwd,
						process = process,
						left = pane_info.left,
						top = pane_info.top,
						width = pane_info.width,
						height = pane_info.height,
					})
				end

				table.insert(tabs_data, {
					title = tab:get_title(),
					active = (tab:tab_id() == active_tab_id),
					panes = panes_data,
				})
			end
		end
	end

	return {
		version = 1,
		workspace = active_workspace,
		last_saved = os.time(),
		tabs = tabs_data,
	}
end

-- Save current workspace to JSON file
-- @return: boolean (true on success, false on failure)
function M.save_current_workspace()
	-- Fast path: skip default workspace before expensive capture.
	local active_workspace = wezterm.mux.get_active_workspace()
	if active_workspace == "default" then
		return false
	end

	local layout = M.capture_workspace()

	-- Defensive check in case active workspace changed mid-capture.
	if layout.workspace == "default" then
		return false
	end

	-- Skip deleted workspaces (auto-save would resurrect them)
	local deleted = wezterm.GLOBAL.deleted_sessions or {}
	if deleted[layout.workspace] then
		return false
	end

	-- Skip empty workspaces
	if #layout.tabs == 0 then
		wezterm.log_warn("save_current_workspace: no tabs in workspace '" .. layout.workspace .. "', skipping save")
		return false
	end

	-- Sanitize workspace name for filename (replace non-alphanumeric except - and _ with _)
	local sanitized_name = layout.workspace:gsub("[^%w%-_]", "_")

	-- Build file paths
	local sessions_dir = M.sessions_dir
	local filename = sessions_dir .. "/" .. sanitized_name .. ".json"
	local temp_file = filename .. ".tmp"

	-- Ensure sessions directory exists (once per session, not every save)
	if not M._dir_ensured then
		local mkdir_result = wezterm.run_child_process({ "mkdir", "-p", sessions_dir })
		if not mkdir_result then
			wezterm.log_error("save_current_workspace: failed to create sessions directory")
			return false
		end
		M._dir_ensured = true
	end

	-- Encode to JSON
	local json = wezterm.json_encode(layout)
	if not json then
		wezterm.log_error("save_current_workspace: JSON encoding failed")
		return false
	end

	-- Write to temp file
	local f, err = io.open(temp_file, "w")
	if not f then
		wezterm.log_error("save_current_workspace: failed to open temp file: " .. tostring(err))
		return false
	end

	local write_ok, write_err = f:write(json)
	f:close()

	if not write_ok then
		wezterm.log_error("save_current_workspace: failed to write JSON: " .. tostring(write_err))
		return false
	end

	-- Atomic rename
	local rename_ok, rename_err = os.rename(temp_file, filename)
	if not rename_ok then
		wezterm.log_error("save_current_workspace: failed to rename temp file: " .. tostring(rename_err))
		return false
	end

	wezterm.log_info("save_current_workspace: saved workspace '" .. layout.workspace .. "' to " .. filename)
	return true
end

-- Load workspace from JSON file
-- @param name: workspace name (will be sanitized)
-- @return: Lua table or nil on error
function M.load_workspace(name)
	-- Sanitize name
	local sanitized_name = name:gsub("[^%w%-_]", "_")

	-- Build file path
	local filename = M.sessions_dir .. "/" .. sanitized_name .. ".json"

	-- Read file
	local f, err = io.open(filename, "r")
	if not f then
		wezterm.log_warn("load_workspace: failed to open file: " .. tostring(err))
		return nil
	end

	local content = f:read("*all")
	f:close()

	if not content then
		wezterm.log_error("load_workspace: failed to read file content")
		return nil
	end

	-- Parse JSON
	local ok, layout = pcall(wezterm.json_parse, content)
	if not ok then
		wezterm.log_error("load_workspace: JSON parse failed: " .. tostring(layout))
		return nil
	end

	return layout
end

return M
