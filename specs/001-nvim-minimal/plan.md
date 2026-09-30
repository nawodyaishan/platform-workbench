# Plan: Neovim minimal config

Spec revision used: `spec.md` as drafted 2026-09-30 (initial draft, no prior revisions).

## Approach

Mirror the existing `vim`/`tmux` module shape exactly, but at directory granularity for the config, plus two installation paths inside the module (`go install`, conditional `npm install -g`) beyond plain `pm_install`, because `gopls`/`ts_ls`/`yamlls` aren't brew-packaged the way `kubectl`/`helm` are.

### Plugin manager: native `vim.pack`, not `lazy.nvim`

Every researched reference config (including `tjdevries/advent-of-nvim`, which the user pointed at directly) uses `lazy.nvim`, bootstrapped with a `git clone` guard at the top of `init.lua`/`lazy.lua`. That pattern predates Neovim 0.12's built-in `vim.pack.add()`. Since this feature is macOS-only and brew always installs current stable Neovim (0.12.5 today), the 0.12 floor is safe, and `vim.pack` removes the bootstrap-clone snippet, the lockfile-management plugin, and `require("lazy").setup()` boilerplate entirely — one small file (`lua/config/pack.lua`) is the whole "plugin manager." `nvim_verify` checks `nvim --version` ≥ 0.12 explicitly so a stale cached brew formula fails loudly instead of silently breaking `vim.pack.add`.

### LSP: native `vim.lsp.config`/`vim.lsp.enable`, no `nvim-lspconfig`

Neovim ≥0.11 ships this natively; adding `nvim-lspconfig` would just be a second source of truth for the same four server tables. `lua/config/lsp.lua` defines `gopls`, `ts_ls`, `yamlls`, `lua_ls` directly with `cmd`/`filetypes`/`root_markers`, then calls `vim.lsp.enable()`. A server whose binary is missing is simply never attached — no error — matching the community pattern found in `wunki/dot-nvim` and `umenorin/minimal-neovim`.

### No Mason

Consistent with this repo never delegating tool installation to an in-app package manager (`lang.sh` installs Go itself, `k8s.sh` installs kubectl itself). `nvim.sh` installs `gopls` via `go install golang.org/x/tools/gopls@latest` (Go already comes from the Brewfile) and attempts `npm install -g typescript-language-server yaml-language-server` only `if have npm`. `lua-language-server` is brew-packaged, so it joins `neovim` in `macos.Brewfile` and is handled by the existing `base_bootstrap`/`brew bundle` path — `nvim.sh` doesn't run its own brew calls for either.

### Plugin set — 4 plugins total

| Plugin | Role | Why this one |
|---|---|---|
| `nvim-treesitter` | parsing/highlighting | the only realistic choice; `main`-branch API, `ensure_installed` limited to the languages in scope |
| `blink.cmp` | completion | prebuilt binary (no Rust toolchain needed at install time), the modern default across every 2025 reference config surveyed |
| `fzf-lua` | fuzzy finder | thin wrapper around the `fzf`/`ripgrep` binaries the Brewfile already installs — no second fuzzy-matching implementation the way Telescope brings one |
| `gitsigns.nvim` | git gutter/hunks | tiny, single-purpose, directly useful while editing tracked Go/TS/YAML files |

No file tree, no dashboard, no DAP, no formatter/linter plugin, no colorscheme plugin — `retrobox` (built into Neovim core since 0.10) is the default colorscheme, set once in `options.lua`. Sensible native-Neovim defaults borrowed from `advent-of-nvim`: `mapleader = " "`, `clipboard = "unnamedplus"`, `relativenumber = true`, and a zero-dependency `TextYankPost` highlight-on-yank autocmd. A `lua/user/init.lua` `pcall(require, "user")` hook at the end of `init.lua` is the escape hatch for personal, unmanaged extras (parallels `~/.vimrc.local`), silently skipped when absent.

Not adopted from `advent-of-nvim`: its `plugin/*.lua` native-autoload directory for standalone features (e.g. `floaterminal.lua`). It's a legitimate zero-dependency technique, but this repo's existing modules (`shell.sh`, `vimrc`) always wire things through one explicit `require`/`source` chain rather than implicit directory scanning, so `init.lua` keeps explicit `require("config.x")` lines for consistency with the rest of this repo, not because the autoload mechanism is worse.

### Formatting: manual, not on save

`vim.lsp.buf.format()` bound to a keymap in `lua/config/keymaps.lua`. No `conform.nvim`, no `goimports`/`prettier` install step — `gopls` and `ts_ls` both already implement `textDocument/formatting`. This keeps the installed-binary surface to exactly: `neovim`, `lua-language-server`, `gopls`, and (optionally, npm-gated) `typescript-language-server`/`yaml-language-server`.

## Affected components

- New: `config/nvim/init.lua`, `config/nvim/lua/config/{options,keymaps,lsp,pack,treesitter}.lua` (5 files, target well under 300 lines total).
- New: `bootstrap/modules/nvim.sh`.
- Changed: `bootstrap/profiles/macos.sh` (`MODULES` gains `nvim`), `bootstrap/profiles/macos.Brewfile` (`neovim`, `lua-language-server`), `docs/config.md` (new "## Neovim" section + table row), `README.md` (macOS profile row).
- Unchanged: everything under `config/vim/`, every non-macOS profile, every other module.

## Design decisions

1. `vim.pack` over `lazy.nvim` — see above.
2. Native LSP over `nvim-lspconfig` — see above.
3. Directory symlink (`~/.config/nvim -> config/nvim`) via the existing `link_file`/`check_link` pair — the same idiom as the single-file symlinks in `shell.sh`. No new helper needed: `ln -s` and `backup_path`'s `mv` both work on directories already.
4. `nvim` module is macOS-only: added only to `bootstrap/profiles/macos.sh`'s `MODULES` array. `rhel.sh`/`ubuntu.sh`/`proxmox.sh` stay untouched, so lab hosts keep vim-only, preserving exam parity by construction rather than by convention alone.
5. `gopls`/`ts_ls`/`yamlls` absence is `na`/`warn`, never `bad` in verify, and never `die` in bootstrap — a missing optional LSP must not fail `task check`/`task bootstrap` for a user who hasn't installed Node.

## Risks

- **`vim.pack` is new** (Neovim 0.12, released 2025) and less battle-tested than `lazy.nvim`. Mitigated by scope (macOS-only, brew always current) and by `nvim_verify` asserting the version floor explicitly.
- **`npm install -g` outside `brew`/`pm_install` is a new install path for this repo.** Mitigated by gating on `have npm` and never treating its absence as failure.
- **`gopls` lands in `$(go env GOPATH)/bin`, which may not be on `PATH`.** `nvim_verify` checks `have gopls` and reports the exact `export PATH` line to add if missing, rather than assuming.
- **Headless smoke test is necessary but not sufficient** — it catches Lua load errors, not LSP/completion behavior, which stays manual per acceptance criterion 3.

## Specialists and tools

- No additional specialist skill needed — this is a bounded, established-pattern bash+Lua config change fully covered by repository conventions already read (`bootstrap/modules/*.sh`, `docs/config.md`, `README.md`).
- Tools: local file read/edit only for implementation. `.codegraph/` exists in this repo, so code-location lookups during implementation use `codegraph_explore` in preference to grep, per the standing rule.
- No live/execution authorization is needed for drafting. Actually running `task bootstrap` on this machine (installing brew formulae, symlinking `~/.config/nvim`, running `go install`) is a real-machine action per this repo's own rule ("Running `task bootstrap` ... without `--dry-run` ... act on real machines and need explicit human authorization every time") and needs separate authorization at batch-execution time, not at drafting time.

## Checks

- `task check` (lint + secrets + repo) must pass with the new module/Brewfile/docs changes.
- `bash -n bootstrap/modules/nvim.sh` and `shellcheck bootstrap/modules/nvim.sh` (part of `task check`).
- `nvim --headless -u config/nvim/init.lua -c 'qa'` exits 0 — the automatable half of acceptance criteria 3/4.
- `bootstrap/workbench.sh bootstrap --profile macos --dry-run` shows the new module's planned actions without making changes.

Next document: `tasks.md`.
