-- Neovim's native plugin manager (0.12+). No bootstrap clone, no lockfile plugin, no
-- separate setup() call to wire it in — this file is the whole "plugin manager".
vim.pack.add({
  { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
  -- Pinned to the v1 branch: main is an actively-developed v2 that additionally
  -- requires saghen/blink.lib installed separately. v1 needs nothing extra.
  { src = "https://github.com/Saghen/blink.cmp", version = "v1" },
  "https://github.com/ibhagwan/fzf-lua",
  "https://github.com/lewis6991/gitsigns.nvim",
})

require("blink.cmp").setup({
  keymap = { preset = "default" },
  sources = { default = { "lsp", "path", "buffer", "snippets" } },
  -- Falls back to the bundled pure-Lua matcher if the prebuilt Rust binary isn't
  -- available, so this works with no build step.
  fuzzy = { implementation = "prefer_rust_with_warning" },
})

require("fzf-lua").setup({})
require("gitsigns").setup({})
