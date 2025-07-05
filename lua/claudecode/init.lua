local M = {}

local config = {
  split_direction = "vertical",
  split_size = 80,
  claude_command = "claude",
  auto_focus = true,
  edit_keymap = "<leader>ce", -- Default keymap for edit command
  modal_height = 8,          -- Height of the terminal modal
  modal_width = 80,          -- Width of the terminal modal
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
    desc = "Open Claude Code in a split",
  })

  vim.api.nvim_create_user_command("ClaudeCodeContinue", function()
    M.open_claude("-c")
  end, {
    desc = "Continue previous Claude Code session",
  })

  vim.api.nvim_create_user_command("ClaudeCodeClose", function()
    M.close_claude()
  end, {
    desc = "Close Claude Code split",
  })

  vim.api.nvim_create_user_command("ClaudeCodeEdit", function(cmd_opts)
    M.edit_selection(cmd_opts.range == 2)
  end, {
    range = true,
    desc = "Edit selected code with Claude",
  })

  -- Set up keymapping if configured
  if config.edit_keymap and config.edit_keymap ~= "" then
    vim.keymap.set("v", config.edit_keymap, ":ClaudeCodeEdit<CR>", {
      desc = "Edit selection with Claude Code",
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

  -- Get user input for the edit instruction using floating input
  M.create_floating_input("How would you like to edit this code? ", function(instruction)
    if not instruction or instruction == "" then
      return
    end

    -- Get the current file path and language
    local filepath = vim.api.nvim_buf_get_name(0)
    local filetype = vim.bo.filetype

    -- Construct the prompt for Claude to edit the file directly
    local prompt = string.format(
      "Edit the file %s\n"
      .. "Find and replace the following code section with an edited version according to this instruction: %s\n\n"
      .. "Code to find and edit:\n%s",
      filepath,
      instruction,
      selected_text
    )

    -- Create floating terminal modal
    M.create_terminal_modal(prompt, start_line)
  end)
end

-- Create a floating input window
function M.create_floating_input(prompt, callback)
  -- Create buffer for input
  local input_buf = vim.api.nvim_create_buf(false, true)
  
  -- Calculate window size and position
  local width = 60
  local height = 3
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  -- Create floating window
  local input_win = vim.api.nvim_open_win(input_buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " " .. prompt,
    title_pos = "center",
  })
  
  -- Set buffer options
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = input_buf })
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = input_buf })
  
  -- Add prompt text
  vim.api.nvim_buf_set_lines(input_buf, 0, -1, false, {"", ""})
  
  -- Position cursor on second line for input
  vim.api.nvim_win_set_cursor(input_win, {2, 0})
  
  -- Enter insert mode
  vim.cmd("startinsert")
  
  -- Function to handle input completion
  local function complete_input()
    local lines = vim.api.nvim_buf_get_lines(input_buf, 0, -1, false)
    local input_text = ""
    
    -- Concatenate all non-empty lines
    for _, line in ipairs(lines) do
      if line ~= "" then
        input_text = input_text .. line .. " "
      end
    end
    
    input_text = vim.trim(input_text)
    
    -- Close the window
    if vim.api.nvim_win_is_valid(input_win) then
      vim.api.nvim_win_close(input_win, true)
    end
    
    -- Call the callback with the input
    callback(input_text)
  end
  
  -- Function to cancel input
  local function cancel_input()
    if vim.api.nvim_win_is_valid(input_win) then
      vim.api.nvim_win_close(input_win, true)
    end
  end
  
  -- Set up keymaps
  vim.keymap.set("i", "<CR>", complete_input, { buffer = input_buf, nowait = true })
  vim.keymap.set("i", "<Esc>", cancel_input, { buffer = input_buf, nowait = true })
  vim.keymap.set("n", "<CR>", complete_input, { buffer = input_buf, nowait = true })
  vim.keymap.set("n", "<Esc>", cancel_input, { buffer = input_buf, nowait = true })
  vim.keymap.set("n", "q", cancel_input, { buffer = input_buf, nowait = true })
end

-- Create a floating terminal modal positioned above the selected lines
function M.create_terminal_modal(prompt, position_line)
  -- Create a new buffer for the terminal
  local modal_buf = vim.api.nvim_create_buf(false, true)

  -- Get editor dimensions
  local editor_width = vim.o.columns
  local editor_height = vim.o.lines

  -- Calculate modal dimensions
  local modal_width = math.min(config.modal_width, editor_width - 4)
  local modal_height = config.modal_height

  -- Calculate position - place modal above the selected line
  local win_line = math.max(0, position_line - modal_height - 1)
  local win_col = math.floor((editor_width - modal_width) / 2)

  -- Ensure modal fits within screen bounds
  if win_line + modal_height > editor_height - 2 then
    win_line = math.max(0, editor_height - modal_height - 2)
  end

  -- Create floating window
  local modal_win = vim.api.nvim_open_win(modal_buf, true, {
    relative = "editor",
    width = modal_width,
    height = modal_height,
    row = win_line,
    col = win_col,
    style = "minimal",
    border = "rounded",
    title = " Claude Code Edit ",
    title_pos = "center",
  })

  -- Set terminal buffer options
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = modal_buf })
  vim.api.nvim_set_option_value("buftype", "terminal", { buf = modal_buf })

  -- Execute Claude command in the modal terminal
  local cmd = string.format("%s -p %q", config.claude_command, prompt)

  local job_id = vim.fn.termopen(cmd, {
    on_exit = function(_, exit_code, _)
      vim.schedule(function()
        -- Close the modal window
        if vim.api.nvim_win_is_valid(modal_win) then
          vim.api.nvim_win_close(modal_win, true)
        end

        if exit_code == 0 then
          -- Reload the file to show changes
          vim.cmd("edit!")
          vim.notify("Claude has completed the edit", vim.log.levels.INFO)
        else
          vim.notify("Claude exited with code: " .. exit_code, vim.log.levels.ERROR)
        end
      end)
    end,
  })

  -- Set up key mappings for the modal
  local function close_modal()
    if vim.api.nvim_win_is_valid(modal_win) then
      vim.api.nvim_win_close(modal_win, true)
    end
    if job_id then
      vim.fn.jobstop(job_id)
    end
  end

  -- Add escape key to close modal
  vim.keymap.set("n", "<Esc>", close_modal, { buffer = modal_buf, nowait = true })
  vim.keymap.set("t", "<Esc>", close_modal, { buffer = modal_buf, nowait = true })

  -- Enter terminal mode
  vim.cmd("startinsert")
end

return M

