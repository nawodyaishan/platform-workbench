local map = vim.keymap.set

-- gd/grn/gra/grr/gri/gO/K are Neovim >=0.11 LSP defaults; only add what's missing.
-- Formatting is manual on purpose (no format-on-save), matching config/vim/vimrc.
map("n", "<leader>f", vim.lsp.buf.format, { desc = "LSP: format buffer" })
map("n", "<leader>e", vim.diagnostic.open_float, { desc = "diagnostics: show line" })
map("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, { desc = "diagnostics: previous" })
map("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, { desc = "diagnostics: next" })

map("n", "<leader>ff", function() require("fzf-lua").files() end, { desc = "find files" })
map("n", "<leader>fg", function() require("fzf-lua").live_grep() end, { desc = "live grep" })
map("n", "<leader>fb", function() require("fzf-lua").buffers() end, { desc = "buffers" })
map("n", "<leader>fh", function() require("fzf-lua").help_tags() end, { desc = "help tags" })
map("n", "<leader>fd", function() require("fzf-lua").diagnostics_document() end, { desc = "document diagnostics" })

map("n", "]c", function() require("gitsigns").next_hunk() end, { desc = "next git hunk" })
map("n", "[c", function() require("gitsigns").prev_hunk() end, { desc = "previous git hunk" })
map("n", "<leader>hs", function() require("gitsigns").stage_hunk() end, { desc = "stage hunk" })
map("n", "<leader>hr", function() require("gitsigns").reset_hunk() end, { desc = "reset hunk" })
map("n", "<leader>hp", function() require("gitsigns").preview_hunk() end, { desc = "preview hunk" })
map("n", "<leader>hb", function() require("gitsigns").blame_line() end, { desc = "blame line" })
