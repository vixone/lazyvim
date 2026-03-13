-- mini-files: file explorer replacing Snacks explorer
-- Based on linkarzu's config, trimmed to essentials

return {
  "nvim-mini/mini.files",
  opts = function(_, opts)
    -- Custom navigation mappings
    opts.mappings = vim.tbl_deep_extend("force", opts.mappings or {}, {
      close = "<esc>",
      go_in = "l",
      go_in_plus = "<CR>",
      go_out = "H",
      go_out_plus = "h",
      reset = "<BS>",
      reveal_cwd = ".",
      show_help = "g?",
      synchronize = "s",
      trim_left = "<",
      trim_right = ">",
    })

    opts.windows = vim.tbl_deep_extend("force", opts.windows or {}, {
      preview = true,
      width_focus = 30,
      width_preview = 80,
    })

    opts.options = vim.tbl_deep_extend("force", opts.options or {}, {
      use_as_default_explorer = true,
      permanent_delete = false,
    })

    return opts
  end,

  keys = {
    {
      "<leader>e",
      function()
        local buf_name = vim.api.nvim_buf_get_name(0)
        local dir_name = vim.fn.fnamemodify(buf_name, ":p:h")
        if vim.fn.filereadable(buf_name) == 1 then
          require("mini.files").open(buf_name, true)
        elseif vim.fn.isdirectory(dir_name) == 1 then
          require("mini.files").open(dir_name, true)
        else
          require("mini.files").open(vim.uv.cwd(), true)
        end
      end,
      desc = "Open mini.files (file dir)",
    },
    {
      "<leader>E",
      function()
        require("mini.files").open(vim.uv.cwd(), true)
      end,
      desc = "Open mini.files (cwd)",
    },
  },

  config = function(_, opts)
    require("mini.files").setup(opts)

    -- Git status integration
    local nsMiniFiles = vim.api.nvim_create_namespace("mini_files_git")
    local gitStatusCache = {}
    local cacheTimeout = 2000

    local gitStatusMap = {
      [" M"] = { symbol = "M", hlGroup = "MiniDiffSignChange" },
      ["M "] = { symbol = "S", hlGroup = "MiniDiffSignChange" },
      ["MM"] = { symbol = "M", hlGroup = "MiniDiffSignChange" },
      ["A "] = { symbol = "A", hlGroup = "MiniDiffSignAdd" },
      ["AA"] = { symbol = "A", hlGroup = "MiniDiffSignAdd" },
      ["AM"] = { symbol = "A", hlGroup = "MiniDiffSignAdd" },
      ["??"] = { symbol = "?", hlGroup = "MiniDiffSignDelete" },
      ["R "] = { symbol = "R", hlGroup = "MiniDiffSignChange" },
      [" D"] = { symbol = "D", hlGroup = "MiniDiffSignDelete" },
      ["D "] = { symbol = "D", hlGroup = "MiniDiffSignDelete" },
      ["DD"] = { symbol = "D", hlGroup = "MiniDiffSignDelete" },
      ["UU"] = { symbol = "C", hlGroup = "DiagnosticSignWarn" },
    }

    local function mapSymbols(status, is_dir)
      if is_dir then
        return { symbol = "+", hlGroup = "MiniDiffSignChange" }
      end
      return gitStatusMap[status] or { symbol = "?", hlGroup = "NonText" }
    end

    local function fetchGitStatus(cwd, callback)
      local stdout = vim.uv.new_pipe()
      local handle
      handle = vim.uv.spawn("git", {
        args = { "status", "--short", "--no-column", "--untracked-files=all" },
        cwd = cwd,
        stdio = { nil, stdout, nil },
      }, function(code)
        if handle then handle:close() end
        if stdout then stdout:close() end
        if code ~= 0 then return end
      end)
      if not stdout then return end

      local output = ""
      stdout:read_start(function(err, data)
        if err then return end
        if data then
          output = output .. data
        else
          -- EOF
          vim.schedule(function()
            local statusMap = {}
            for line in output:gmatch("[^\n]+") do
              local status = line:sub(1, 2)
              local filePath = line:sub(4)
              -- Handle renames: "R  old -> new"
              if status:sub(1, 1) == "R" then
                filePath = filePath:match("-> (.+)") or filePath
              end
              statusMap[filePath] = status
              -- Also mark parent directories
              local dir = vim.fn.fnamemodify(filePath, ":h")
              while dir ~= "." and dir ~= "" do
                if not statusMap[dir] then
                  statusMap[dir] = "dir"
                end
                dir = vim.fn.fnamemodify(dir, ":h")
              end
            end
            gitStatusCache = statusMap
            callback()
          end)
        end
      end)
    end

    local function updateMiniWithGit(buf_id, gitStatusMap_local)
      vim.schedule(function()
        local nlines = vim.api.nvim_buf_line_count(buf_id)
        local cwd = vim.fn.expand("%:p:h")
        local escapedcwd = vim.pesc(cwd)
        for i = 1, nlines do
          local entry = MiniFiles.get_fs_entry(buf_id, i)
          if entry then
            local relPath = entry.path:gsub("^" .. escapedcwd .. "/", "")
            local status = cycleGitStatus(relPath, gitStatusMap_local, entry.fs_type == "directory")
            if status then
              local symbols = mapSymbols(status, entry.fs_type == "directory")
              vim.api.nvim_buf_set_extmark(buf_id, nsMiniFiles, i - 1, 0, {
                sign_text = symbols.symbol,
                sign_hl_group = symbols.hlGroup,
                priority = 2,
              })
            end
          end
        end
      end)
    end

    -- Simplified: check if path or any child has git status
    function cycleGitStatus(path, statusMap, is_dir)
      if statusMap[path] then
        return statusMap[path]
      end
      if is_dir then
        for p, s in pairs(statusMap) do
          if vim.startswith(p, path .. "/") then
            return "dir"
          end
        end
      end
      return nil
    end

    -- Autocmd: refresh git on explorer open
    vim.api.nvim_create_autocmd("User", {
      pattern = "MiniFilesExplorerOpen",
      callback = function()
        local cwd = vim.fn.getcwd()
        fetchGitStatus(cwd, function() end)
      end,
    })

    -- Autocmd: apply git status to buffer
    vim.api.nvim_create_autocmd("User", {
      pattern = "MiniFilesBufferUpdate",
      callback = function(args)
        local buf_id = args.data.buf_id
        if gitStatusCache and next(gitStatusCache) then
          updateMiniWithGit(buf_id, gitStatusCache)
        end
      end,
    })

    -- NOTE: Image preview not supported — WezTerm lacks unicode placeholders
    -- needed for inline image rendering in floating windows. Would work on
    -- Kitty or Ghostty terminals.
  end,
}
