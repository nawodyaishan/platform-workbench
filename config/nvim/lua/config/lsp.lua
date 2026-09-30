-- Native LSP (Neovim >=0.11): vim.lsp.config/vim.lsp.enable, no nvim-lspconfig.
vim.lsp.config("*", { root_markers = { ".git" } })

vim.lsp.config("lua_ls", {
  cmd = { "lua-language-server" },
  filetypes = { "lua" },
  root_markers = { ".luarc.json", ".luarc.jsonc", ".git" },
  settings = {
    Lua = {
      diagnostics = { globals = { "vim" } },
      workspace = { checkThirdParty = false },
    },
  },
})

vim.lsp.config("gopls", {
  cmd = { "gopls" },
  filetypes = { "go", "gomod", "gowork", "gotmpl" },
  root_markers = { "go.work", "go.mod", ".git" },
})

vim.lsp.config("ts_ls", {
  cmd = { "typescript-language-server", "--stdio" },
  filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
  root_markers = { "package.json", "tsconfig.json", ".git" },
})

vim.lsp.config("yamlls", {
  cmd = { "yaml-language-server", "--stdio" },
  filetypes = { "yaml" },
  root_markers = { ".git" },
  settings = {
    yaml = { keyOrdering = false },
  },
})

-- Only enable a server whose binary is actually on PATH, so a machine without Node
-- (ts_ls/yamlls) or without Go (gopls) just gets fewer servers, not an error.
local function enable_if_present(name, binary)
  if vim.fn.executable(binary or name) == 1 then
    vim.lsp.enable(name)
  end
end

enable_if_present("lua_ls", "lua-language-server")
enable_if_present("gopls")
enable_if_present("ts_ls", "typescript-language-server")
enable_if_present("yamlls", "yaml-language-server")
