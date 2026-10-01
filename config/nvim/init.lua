-- Byte-code cache for Lua modules: faster startup. Must come before the requires.
vim.loader.enable()

require("config.options")
require("config.pack")
require("config.treesitter")
require("config.lsp")
require("config.keymaps")

-- Personal, unmanaged overrides (extra plugins, a different colorscheme). Not part of
-- this repo, so a fresh machine and this config stay minimal without it. Mirrors
-- config/vim/vimrc's ~/.vimrc.local.
pcall(require, "user")
