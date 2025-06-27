# claudecode.nvim

A Neovim plugin that integrates [Claude Code](https://claude.ai/code) directly into your editor through a terminal split window.

## Features

- Open Claude Code in a vertical or horizontal split
- Continue previous Claude Code sessions
- Configurable split size and direction
- Automatic focus on terminal when opened
- Clean session management

## Requirements

- Neovim 0.7.0+
- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed and accessible in your PATH

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "clogginsdev/claudecode.nvim",
  opts = {
    -- your configuration
  }
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "clogginsdev/claudecode.nvim",
  config = function()
    require("claudecode").setup({
      -- your configuration
    })
  end
}
```

## Configuration

Default configuration:

```lua
{
  split_direction = "vertical",  -- "vertical" or "horizontal"
  split_size = 80,               -- width for vertical, height for horizontal
  claude_command = "claude",     -- command to run Claude Code
  auto_focus = true,             -- auto-focus terminal when opened
}
```

## Usage

### Commands

- `:ClaudeCode` - Open Claude Code in a new split
- `:ClaudeCode <args>` - Open Claude Code with additional arguments
- `:ClaudeCodeContinue` - Continue the previous Claude Code session (equivalent to `claude -c`)
- `:ClaudeCodeClose` - Close the Claude Code split

### Example Workflow

1. Open a file you want to work on
2. Run `:ClaudeCode` to open Claude Code in a split
3. Ask Claude to help with your code
4. Use `Ctrl+C` to stop Claude Code when done
5. Run `:ClaudeCodeClose` to close the split

### Tips

- The plugin prevents multiple Claude Code instances from running simultaneously
- If a session is already active, `:ClaudeCode` will focus the existing window
- The terminal buffer is automatically cleaned up when closed to prevent naming conflicts

## License

MIT