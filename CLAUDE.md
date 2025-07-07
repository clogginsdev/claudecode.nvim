# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Neovim plugin called `claudecode.nvim` that integrates Claude Code functionality directly into Neovim by creating a terminal split that runs Claude Code instances.

## Plugin Structure

```
claudecode.nvim/
├── lua/
│   └── claudecode/
│       └── init.lua          # Main plugin logic
├── plugin/
│   └── claudecode.lua        # Plugin initialization
├── README.md
└── CLAUDE.md
```

## Commands Available

- `:ClaudeCode [args]` - Opens Claude Code in a split (optionally with arguments)
- `:ClaudeCodeContinue` - Continues previous Claude Code session (equivalent to `claude -c`)
- `:ClaudeCodeClose` - Closes the Claude Code split

## Configuration

The plugin can be configured via the setup function:

```lua
require("claudecode").setup({
  split_direction = "vertical",  -- "vertical" or "horizontal"
  split_size = 80,               -- Width for vertical, height for horizontal
  claude_command = "claude",     -- Command to run Claude Code
  auto_focus = true,             -- Auto-focus the terminal when opened
})
```

## Plugin Architecture

### Core Components

1. **State Management**: Tracks buffer, window, job ID, and session status
2. **Terminal Integration**: Uses `vim.fn.termopen()` to run Claude Code in a terminal buffer
3. **Window Management**: Creates splits and manages window positioning
4. **Command Interface**: Provides user commands for interaction

### Key Functions

- `M.setup(opts)` - Initializes plugin with user configuration
- `M.open_claude(args)` - Opens Claude Code terminal split
- `M.close_claude()` - Closes Claude Code session
- `M.send_to_claude(text)` - Sends text to active Claude session

## Development Notes

- Uses Neovim's terminal API for seamless integration
- Requires Neovim 0.7.0+ for modern Lua API support
- Terminal buffer is set as unlisted and no-swap
- Session state prevents multiple instances from opening simultaneously
- Supports both vertical and horizontal splits with configurable sizing

## Commit Preferences

- Do not add co-author lines to commits
- Do not include "Generated with Claude Code" attribution in commit messages