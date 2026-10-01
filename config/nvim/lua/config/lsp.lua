-- Native LSP (Neovim >=0.11): vim.lsp.config/vim.lsp.enable, no nvim-lspconfig.

vim.diagnostic.config({
  severity_sort = true,
  update_in_insert = false,
  float = { border = "rounded", source = "if_many" },
  underline = { severity = { min = vim.diagnostic.severity.WARN } },
  -- Show the message when jumping with [d / ]d instead of only moving the cursor.
  jump = {
    on_jump = function(_, bufnr)
      vim.diagnostic.open_float({ bufnr = bufnr, scope = "cursor", focus = false })
    end,
  },
})
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

-- Per-buffer extras once a server attaches. gd/grn/gra/grr/gri/gO/K are 0.11 defaults;
-- the fzf-lua pickers below replace the quickfix-list versions of references and symbols.
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("workbench-lsp-attach", { clear = true }),
  callback = function(ev)
    local function map(lhs, fn, desc)
      vim.keymap.set("n", lhs, fn, { buffer = ev.buf, desc = "LSP: " .. desc })
    end
    local fzf = function(picker)
      return function() require("fzf-lua")[picker]() end
    end
    map("grr", fzf("lsp_references"), "references")
    map("gri", fzf("lsp_implementations"), "implementations")
    map("grt", fzf("lsp_typedefs"), "type definition")
    map("gO", fzf("lsp_document_symbols"), "document symbols")
    map("gW", fzf("lsp_live_workspace_symbols"), "workspace symbols")

    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client:supports_method("textDocument/documentHighlight", ev.buf) then
      local group = vim.api.nvim_create_augroup("workbench-lsp-highlight-" .. ev.buf, { clear = true })
      vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
        buffer = ev.buf, group = group, callback = vim.lsp.buf.document_highlight,
      })
      vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        buffer = ev.buf, group = group, callback = vim.lsp.buf.clear_references,
      })
    end
    if client and client:supports_method("textDocument/inlayHint", ev.buf) then
      map("<leader>th", function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
      end, "toggle inlay hints")
    end
  end,
})
