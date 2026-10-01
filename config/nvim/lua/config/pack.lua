-- Neovim's native plugin manager (0.12+). No bootstrap clone, no lockfile plugin, no
-- separate setup() call to wire it in — this file is the whole "plugin manager."

-- Must be registered before vim.pack.add so a first install also triggers it.
-- nvim-treesitter parsers must be rebuilt after every plugin update or they drift.
vim.api.nvim_create_autocmd("PackChanged", {
  group = vim.api.nvim_create_augroup("workbench-pack-changed", { clear = true }),
  callback = function(ev)
    local data = ev.data
    if data.spec.name == "nvim-treesitter" and (data.kind == "install" or data.kind == "update") then
      if not data.active then
        vim.cmd.packadd("nvim-treesitter")
      end
      pcall(vim.cmd, "TSUpdate")
    end
  end,
})

vim.pack.add({
  { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "main" },
  -- Pinned to the v1 branch: main is an actively-developed v2 that additionally
  -- requires saghen/blink.lib installed separately. v1 needs nothing extra.
  { src = "https://github.com/Saghen/blink.cmp", version = "v1" },
  "https://github.com/ibhagwan/fzf-lua",
  "https://github.com/lewis6991/gitsigns.nvim",
  "https://github.com/folke/which-key.nvim",
  "https://github.com/nvim-mini/mini.surround",
})

require("blink.cmp").setup({
  keymap = { preset = "default" },
  sources = { default = { "lsp", "path", "buffer", "snippets" } },
  -- Falls back to the bundled pure-Lua matcher if the prebuilt Rust binary isn't
  -- available, so this works with no build step.
  fuzzy = { implementation = "prefer_rust_with_warning" },
  signature = { enabled = true },
})

require("fzf-lua").setup({})

-- Hunk keymaps live in config.keymaps (loaded after this file; on_attach runs later).
require("gitsigns").setup({
  on_attach = function(bufnr)
    require("config.keymaps").gitsigns_attach(bufnr)
  end,
})

-- Delay 0: show pending keys immediately; this is a discoverability aid, not a hint.
require("which-key").setup({
  delay = 0,
  icons = { mappings = false }, -- no Nerd Font assumption (SSH, other terminals)
  spec = {
    { "<leader>f", group = "find" },
    { "<leader>c", group = "code" },
    { "<leader>h", group = "git hunk", mode = { "n", "v" } },
    { "<leader>t", group = "toggle" },
    { "gr", group = "LSP actions" },
  },
})

-- sa/sd/sr: add, delete, replace surroundings (e.g. saiw) , sd' , sr)').
require("mini.surround").setup()
