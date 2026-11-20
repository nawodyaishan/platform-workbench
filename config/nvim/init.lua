-- This config uses vim.pack and the PackChanged event, both new in 0.12. Stop here on an
-- older nvim (for example /usr/bin/nvim on Ubuntu) with a readable message, not a traceback.
if vim.fn.has("nvim-0.12") == 0 then
  local v = vim.version()
  vim.api.nvim_echo({
    {
      ("config/nvim needs Neovim 0.12+, but this is %d.%d.%d. Put ~/.local/opt/nvim/bin first on PATH."):format(
        v.major, v.minor, v.patch),
      "ErrorMsg",
    },
  }, true, {})
  return
end

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
