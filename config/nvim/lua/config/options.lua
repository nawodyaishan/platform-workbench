vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.clipboard = "unnamedplus"
vim.opt.mouse = "a"
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.signcolumn = "yes"
vim.opt.background = "dark"
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300
vim.opt.undofile = true

vim.opt.showmode = false -- the mode is in the statusline/cursor already
vim.opt.breakindent = true
vim.opt.cursorline = true
vim.opt.scrolloff = 10
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.inccommand = "split" -- live preview of :s substitutions
vim.opt.confirm = true -- ask to save instead of failing :q on unsaved buffers

-- YAML/Kubernetes manifests: two spaces, never a tab (matches config/vim/vimrc).
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2
vim.opt.autoindent = true

vim.api.nvim_create_autocmd("FileType", {
  desc = "YAML: two-space indentation regardless of other filetype defaults",
  group = vim.api.nvim_create_augroup("workbench-yaml-indent", { clear = true }),
  pattern = "yaml",
  callback = function()
    vim.bo.expandtab = true
    vim.bo.tabstop = 2
    vim.bo.shiftwidth = 2
    vim.bo.softtabstop = 2
  end,
})

-- Search the repository with ripgrep when it is installed; quickfix reads its format.
if vim.fn.executable("rg") == 1 then
  vim.opt.grepprg = "rg --vimgrep --smart-case"
  vim.opt.grepformat = "%f:%l:%c:%m"
end

-- Bundled with Neovim; no plugin or network fetch needed. Its dark palette suits
-- Ghostty -> SSH -> tmux without depending on terminal colour support.
vim.cmd.colorscheme("habamax")

vim.api.nvim_create_autocmd("TextYankPost", {
  desc = "Highlight when yanking (copying) text",
  group = vim.api.nvim_create_augroup("workbench-highlight-yank", { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})
