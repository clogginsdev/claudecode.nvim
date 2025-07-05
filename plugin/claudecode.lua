if vim.g.loaded_claudecode then
  return
end

-- Check for minimum Neovim version requirement
if vim.fn.has("nvim-0.7.0") ~= 1 then
  vim.api.nvim_err_writeln("claudecode.nvim requires nvim-0.7.0+")
  return
end

vim.g.loaded_claudecode = true

require("claudecode").setup()