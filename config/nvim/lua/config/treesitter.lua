local langs = {
  "bash", "go", "gomod", "gowork", "javascript", "json",
  "lua", "markdown", "markdown_inline", "typescript", "tsx", "yaml",
}

require("nvim-treesitter").setup({
  ensure_installed = langs,
  auto_install = true,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = {
    "sh", "bash", "go", "gomod", "gowork", "javascript", "javascriptreact",
    "json", "jsonc", "lua", "markdown", "typescript", "typescriptreact", "yaml",
  },
  group = vim.api.nvim_create_augroup("workbench-treesitter", { clear = true }),
  callback = function()
    -- pcall: the parser may still be downloading on a machine's very first launch.
    pcall(vim.treesitter.start)
  end,
})
