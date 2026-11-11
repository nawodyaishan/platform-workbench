-- Personal, unmanaged overrides loaded by init.lua's pcall(require, "user").
-- Herdr: persistent Neovim sidebar + annotations sent back to the agent.
vim.pack.add({
  "https://github.com/ChmaraX/herdr-nvim",
})

local ok, herdr = pcall(require, "herdr-nvim")
if ok then
  herdr.setup({})
end
