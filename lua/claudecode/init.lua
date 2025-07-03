local M = {}

local config = {
  split_direction = "vertical",
  split_size = 80,
  claude_command = "claude",
  auto_focus = true,
  edit_keymap = "<leader>ce",  -- Default keymap for edit command
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
  
  vim.api.nvim_create_user_command("ClaudeCodeEdit", function(cmd_opts)
    M.edit_selection(cmd_opts.range == 2)
  end, {
    range = true,
    desc = "Edit selected code with Claude"
  })
  
  -- Set up keymapping if configured
  if config.edit_keymap and config.edit_keymap ~= "" then
    vim.keymap.set("v", config.edit_keymap, ":ClaudeCodeEdit<CR>", {
      desc = "Edit selection with Claude Code"
    })
  end
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

-- Get selected text from visual mode
local function get_visual_selection()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local start_line = start_pos[2]
  local end_line = end_pos[2]
  local start_col = start_pos[3]
  local end_col = end_pos[3]
  
  local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  
  -- Handle single line selection
  if #lines == 1 then
    lines[1] = string.sub(lines[1], start_col, end_col)
  else
    -- Handle multi-line selection
    lines[1] = string.sub(lines[1], start_col)
    if #lines > 1 then
      lines[#lines] = string.sub(lines[#lines], 1, end_col)
    end
  end
  
  return lines, start_line - 1, end_line
end

function M.edit_selection(is_visual)
  local lines, start_line, end_line
  
  if is_visual then
    lines, start_line, end_line = get_visual_selection()
  else
    -- If not visual mode, get current line
    local current_line = vim.api.nvim_win_get_cursor(0)[1]
    lines = vim.api.nvim_buf_get_lines(0, current_line - 1, current_line, false)
    start_line = current_line - 1
    end_line = current_line
  end
  
  local selected_text = table.concat(lines, "\n")
  
  -- Get user input for the edit instruction
  vim.ui.input({
    prompt = "How would you like to edit this code? ",
    default = "",
  }, function(instruction)
    if not instruction or instruction == "" then
      return
    end
    
    -- Get the current file path and language
    local filepath = vim.api.nvim_buf_get_name(0)
    local filetype = vim.bo.filetype
    
    -- Construct the prompt for Claude
    local prompt = string.format(
      "Edit the following %s code according to this instruction: %s\n\n" ..
      "Return ONLY the edited code without any explanation or markdown code blocks.\n\n" ..
      "Original code:\n%s",
      filetype,
      instruction,
      selected_text
    )
    
    -- Create a temporary file with the prompt
    local tmp_file = vim.fn.tempname()
    local file = io.open(tmp_file, "w")
    file:write(prompt)
    file:close()
    
    -- Execute Claude in headless mode
    local cmd = string.format("%s -p \"$(cat %s)\" --output-format text", config.claude_command, tmp_file)
    
    vim.fn.jobstart(cmd, {
      stdout_buffered = true,
      on_stdout = function(_, data, _)
        if data and #data > 0 then
          -- Filter out empty strings
          local result = {}
          for _, line in ipairs(data) do
            if line ~= "" then
              table.insert(result, line)
            end
          end
          
          if #result > 0 then
            -- Replace the selected text with the edited version
            vim.api.nvim_buf_set_lines(0, start_line, end_line, false, result)
            vim.notify("Code edited successfully", vim.log.levels.INFO)
          end
        end
      end,
      on_stderr = function(_, data, _)
        if data and #data > 0 and data[1] ~= "" then
          vim.notify("Claude Code error: " .. table.concat(data, "\n"), vim.log.levels.ERROR)
        end
      end,
      on_exit = function(_, exit_code, _)
        -- Clean up temp file
        os.remove(tmp_file)
        
        if exit_code ~= 0 then
          vim.notify("Claude Code exited with code: " .. exit_code, vim.log.levels.ERROR)
        end
      end,
    })
  end)
end

return M