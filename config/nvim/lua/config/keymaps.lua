local map = vim.keymap.set
local M = {}

-- gd/grn/gra/grr/gri/gO/K are Neovim >=0.11 LSP defaults; LSP-attached extras live in
-- config.lsp. Formatting is manual on purpose (no format-on-save), matching
-- config/vim/vimrc. It sits under <leader>c so it never shares a prefix with the
-- <leader>f* pickers (a bare <leader>f would wait timeoutlen for a second key).
map("n", "<leader>cf", vim.lsp.buf.format, { desc = "LSP: format buffer" })
map("n", "<leader>e", vim.diagnostic.open_float, { desc = "diagnostics: show line" })
map("n", "<leader>q", vim.diagnostic.setloclist, { desc = "diagnostics: location list" })
map("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, { desc = "diagnostics: previous" })
map("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, { desc = "diagnostics: next" })

map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "clear search highlight" })
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "exit terminal mode" })
map("n", "<C-h>", "<C-w><C-h>", { desc = "focus left window" })
map("n", "<C-j>", "<C-w><C-j>", { desc = "focus lower window" })
map("n", "<C-k>", "<C-w><C-k>", { desc = "focus upper window" })
map("n", "<C-l>", "<C-w><C-l>", { desc = "focus right window" })

local function fzf(picker, opts)
  return function() require("fzf-lua")[picker](opts) end
end
map("n", "<leader>ff", fzf("files"), { desc = "find files" })
map("n", "<leader>fg", fzf("live_grep"), { desc = "live grep" })
map({ "n", "v" }, "<leader>fw", fzf("grep_cword"), { desc = "grep word under cursor" })
map("n", "<leader>fb", fzf("buffers"), { desc = "buffers" })
map("n", "<leader><leader>", fzf("buffers"), { desc = "buffers" })
map("n", "<leader>fr", fzf("resume"), { desc = "resume last picker" })
map("n", "<leader>fo", fzf("oldfiles"), { desc = "recent files" })
map("n", "<leader>fk", fzf("keymaps"), { desc = "keymaps" })
map("n", "<leader>fh", fzf("help_tags"), { desc = "help tags" })
map("n", "<leader>fd", fzf("diagnostics_document"), { desc = "document diagnostics" })
map("n", "<leader>/", fzf("blines"), { desc = "fuzzy search current buffer" })

-- Called from gitsigns' on_attach (config.pack), so the maps are buffer-local to
-- tracked files and ]c/[c still fall back to the native diff motions in diff mode.
function M.gitsigns_attach(bufnr)
  local gs = require("gitsigns")
  local function bmap(mode, lhs, fn, desc)
    map(mode, lhs, fn, { buffer = bufnr, desc = desc })
  end
  local function nav(dir, key)
    return function()
      if vim.wo.diff then
        vim.cmd.normal({ key, bang = true })
      else
        gs.nav_hunk(dir)
      end
    end
  end
  bmap("n", "]c", nav("next", "]c"), "next git hunk")
  bmap("n", "[c", nav("prev", "[c"), "previous git hunk")
  bmap("n", "<leader>hs", gs.stage_hunk, "stage hunk")
  bmap("n", "<leader>hr", gs.reset_hunk, "reset hunk")
  bmap("v", "<leader>hs", function() gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "stage hunk")
  bmap("v", "<leader>hr", function() gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") }) end, "reset hunk")
  bmap("n", "<leader>hS", gs.stage_buffer, "stage buffer")
  bmap("n", "<leader>hR", gs.reset_buffer, "reset buffer")
  bmap("n", "<leader>hp", gs.preview_hunk, "preview hunk")
  bmap("n", "<leader>hi", gs.preview_hunk_inline, "preview hunk inline")
  bmap("n", "<leader>hb", function() gs.blame_line({ full = true }) end, "blame line")
  bmap("n", "<leader>hd", gs.diffthis, "diff against index")
  bmap("n", "<leader>hD", function() gs.diffthis("~") end, "diff against last commit")
  bmap("n", "<leader>tb", gs.toggle_current_line_blame, "toggle line blame")
  bmap({ "o", "x" }, "ih", gs.select_hunk, "inside hunk")
end

return M
