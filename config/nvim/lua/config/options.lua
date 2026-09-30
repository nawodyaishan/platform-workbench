vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.clipboard = "unnamedplus"
vim.opt.mouse = "a"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 250
vim.opt.undofile = true

-- YAML/Kubernetes manifests: two spaces, never a tab (matches config/vim/vimrc).
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2
vim.opt.autoindent = true

-- Built into Neovim core since 0.10; no colorscheme plugin needed for a minimal setup.
vim.cmd.colorscheme("retrobox")

vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking (copying) text",
  group = vim.api.nvim_create_augroup("workbench-highlight-yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})
