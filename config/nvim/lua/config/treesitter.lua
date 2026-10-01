local ts = require("nvim-treesitter")

local langs = {
  "bash", "go", "gomod", "gowork", "javascript", "json",
  "lua", "markdown", "markdown_inline", "typescript", "tsx", "yaml",
}
ts.install(langs)

-- Enable treesitter highlighting for every filetype that has a parser, installing a
-- missing one on first use. pcall: the parser may still be downloading on a machine's
-- very first launch, and a filetype without a parser must stay silent.
local function attach(buf, lang)
  if vim.api.nvim_buf_is_valid(buf) and vim.treesitter.language.add(lang) then
    pcall(vim.treesitter.start, buf, lang)
  end
end

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("workbench-treesitter", { clear = true }),
  callback = function(args)
    local lang = vim.treesitter.language.get_lang(args.match)
    if not lang then
      return
    end
    if vim.tbl_contains(ts.get_installed("parsers"), lang) then
      attach(args.buf, lang)
    elseif vim.tbl_contains(ts.get_available(), lang) then
      ts.install(lang):await(function()
        attach(args.buf, lang)
      end)
    end
  end,
})
