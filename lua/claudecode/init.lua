local M = {}

local config = {
  split_direction = "vertical",
  split_size = 80,
  claude_command = "claude",
  auto_focus = true,
}

local state = {
  buf = nil,
  win = nil,
  job_id = nil,
  session_active = false,
}

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
  
  vim.api.nvim_create_user_command("ClaudeCode", function(cmd_opts)
    M.open_claude(cmd_opts.args)
  end, {
    nargs = "?",
    desc = "Open Claude Code in a split"
  })
  
  vim.api.nvim_create_user_command("ClaudeCodeContinue", function()
    M.open_claude("-c")
  end, {
    desc = "Continue previous Claude Code session"
  })
  
  vim.api.nvim_create_user_command("ClaudeCodeClose", function()
    M.close_claude()
  end, {
    desc = "Close Claude Code split"
  })
end

function M.open_claude(args)
  if state.session_active then
    if state.win and vim.api.nvim_win_is_valid(state.win) then
      vim.api.nvim_set_current_win(state.win)
    end
    return
  end
  
  -- Create split with a new buffer
  local split_cmd = config.split_direction == "vertical" and "vsplit" or "split"
  vim.cmd(split_cmd .. " new")
  
  -- Store references to the new window and buffer
  state.win = vim.api.nvim_get_current_win()
  state.buf = vim.api.nvim_get_current_buf()
  
  -- Set window size
  if config.split_direction == "vertical" then
    vim.api.nvim_win_set_width(state.win, config.split_size)
  else
    vim.api.nvim_win_set_height(state.win, config.split_size)
  end
  
  -- Build the command
  local claude_cmd = config.claude_command
  if args and args ~= "" then
    claude_cmd = claude_cmd .. " " .. args
  end
  
  -- Open terminal in the new buffer
  state.job_id = vim.fn.termopen(claude_cmd, {
    on_exit = function(_, exit_code, _)
      state.session_active = false
      state.job_id = nil
      state.buf = nil
    end,
  })
  
  -- Set buffer name, but only if it doesn't conflict
  pcall(vim.api.nvim_buf_set_name, state.buf, "Claude Code")
  
  state.session_active = true
  
  if config.auto_focus then
    vim.cmd("startinsert")
  end
end

function M.close_claude()
  if state.job_id then
    vim.fn.jobstop(state.job_id)
    state.job_id = nil
  end
  
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
    state.win = nil
  end
  
  -- Delete the buffer to free up the name
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    vim.api.nvim_buf_delete(state.buf, { force = true })
  end
  
  state.buf = nil
  state.session_active = false
end

function M.send_to_claude(text)
  if not state.job_id then
    vim.notify("No active Claude Code session", vim.log.levels.WARN)
    return
  end
  
  vim.fn.chansend(state.job_id, text .. "\n")
end

return M