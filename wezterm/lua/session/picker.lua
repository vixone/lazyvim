-- Session picker - fuzzy searchable session selector overlay
local wezterm = require("wezterm")
local act = wezterm.action
local manager = require("lua.session.manager")

local M = {}

-- Show fuzzy picker for session selection
-- @param window: WezTerm window object
-- @param pane: WezTerm pane object
-- @param mode: "switch" or "delete" (default: "switch")
-- @param exclude: session name to exclude from list (used after async delete)
function M.show_picker(window, pane, mode, exclude)
	mode = mode or "switch"
	-- Get current workspace
	local current = wezterm.mux.get_active_workspace()

	-- Get all sessions
	local sessions = manager.list_sessions()

	-- Build active session lookup for callback
	-- (activate-pane CLI doesn't switch GUI workspace; we need SwitchToWorkspace action)
	local active_sessions = {}
	for _, session in ipairs(sessions) do
		if session.active then
			active_sessions[session.name] = true
		end
	end

	-- Build choices array based on mode
	local choices = {}
	local title = "Sessions"

	if mode == "delete" then
		-- DELETE MODE: Show trash-prefixed sessions
		title = "Sessions [DELETE]"

		for _, session in ipairs(sessions) do
			-- Skip recently-deleted session (async close may still be in mux)
			if session.name == exclude then
				-- noop: skip
			elseif session.name == current then
				-- Current session: no trash icon, not deletable
				table.insert(choices, {
					id = session.name,
					label = "  " .. session.name .. " (current)",
				})
			else
				-- Deletable session: x prefix
				table.insert(choices, {
					id = session.name,
					label = "x " .. session.name,
				})
			end
		end

		-- Append back-to-switch sentinel
		table.insert(choices, {
			id = "__back__",
			label = "< Back to sessions...",
		})
	else
		-- SWITCH MODE: Original behavior
		-- Filter out excluded session (async delete still in mux)
		local filtered_sessions = {}
		for _, session in ipairs(sessions) do
			if session.name ~= exclude then
				filtered_sessions[#filtered_sessions + 1] = session
			end
		end
		sessions = filtered_sessions

		if #sessions == 0 then
			-- No sessions - add informational message
			table.insert(choices, {
				id = "__empty__",
				label = "No sessions found",
			})
		else
			-- Add each session with prefix
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

		-- Append delete-mode sentinel if deletable sessions exist
		if has_deletable then
			table.insert(choices, {
				id = "__delete_mode__",
				label = "x Delete mode...",
			})
		end
	end

	-- Show InputSelector
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

				-- DELETE MODE HANDLERS
				if mode == "delete" then
					-- User selected back-to-switch sentinel
					if id == "__back__" then
						M.show_picker(inner_window, inner_pane, "switch")
						return
					end

					-- User selected current session (silent no-op)
					if id == current then
						return
					end

					-- User selected a deletable session - confirm deletion
					inner_window:perform_action(
						act.PromptInputLine({
							description = "Delete '" .. id .. "'? Type 'yes' to confirm:",
							action = wezterm.action_callback(function(win, p, line)
								-- User pressed Escape or cancelled
								if not line then
									M.show_picker(win, p, "delete")
									return
								end

								-- Check for confirmation
								local normalized = string.lower(line)
								if normalized ~= "y" and normalized ~= "yes" then
									-- Cancelled - return to delete mode
									M.show_picker(win, p, "delete")
									return
								end

								-- Confirmed - delete the session
								local ok, err = manager.delete_session(id)
								if not ok then
									win:toast_notification(
										"Delete Error",
										err or "Failed to delete session",
										nil,
										3000
									)
									M.show_picker(win, p, "delete")
									return
								end

								-- Deletion successful - return to delete mode and
								-- hide the just-deleted session while mux shutdown catches up.
								M.show_picker(win, p, "delete", id)
							end),
						}),
						inner_pane
					)
					return
				end

				-- SWITCH MODE HANDLERS
				-- User selected empty placeholder
				if id == "__empty__" then
					return
				end

				-- User selected create-new sentinel
				if id == "__create__" then
					inner_window:perform_action(
						act.PromptInputLine({
							description = "New session name",
							action = wezterm.action_callback(function(win, p, line)
								if not line or line == "" then
									return
								end
								if not line:match("^[%w%-_]+$") then
									win:toast_notification(
										"Session Error",
										"Name: alphanumeric, dashes, underscores only",
										nil,
										3000
									)
									return
								end
								-- SwitchToWorkspace creates workspace in the SAME GUI window
								-- (spawn_window would open a new small window)
								win:perform_action(
									act.SwitchToWorkspace({ name = line }),
									p
								)
							end),
						}),
						inner_pane
					)
					return
				end

				-- User selected delete-mode sentinel
				if id == "__delete_mode__" then
					M.show_picker(inner_window, inner_pane, "delete")
					return
				end

				-- User selected current session (silent no-op)
				if id == current then
					return
				end

				-- User selected a different session - switch to it
				if active_sessions[id] then
					-- Running workspace: use GUI action to switch
					-- (activate-pane CLI only changes mux focus, not GUI workspace)
					inner_window:perform_action(
						act.SwitchToWorkspace({ name = id }),
						inner_pane
					)
				else
					-- Saved-only: restore layout from JSON, then switch GUI
					local ok, err = manager.restore_session(id)
					if not ok then
						inner_window:toast_notification("Session Error", err or "Failed to restore", nil, 3000)
						return
					end
					inner_window:perform_action(
						act.SwitchToWorkspace({ name = id }),
						inner_pane
					)
				end
			end),
		}),
		pane
	)
end

return M
