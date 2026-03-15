-- Session management entry point
local state = require("lua.session.state")
local manager = require("lua.session.manager")
local picker = require("lua.session.picker")

local M = {}

-- Expose submodules
M.state = state
M.manager = manager
M.picker = picker

-- Apply session configuration to WezTerm config
-- @param config: WezTerm config table
-- @param opts: { enabled = boolean } (default: { enabled = true })
function M.apply_to_config(config, opts)
	opts = opts or { enabled = true }
	if not opts.enabled then
		return
	end
	-- Sessions use WezTerm's built-in local mux (workspaces + auto-save).
	-- No unix_domains or daemon needed.
end

return M
