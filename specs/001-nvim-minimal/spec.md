# Neovim minimal config (daily TS/Go/YAML editor)

## Outcome

Add a second, separate editor config — Neovim — for daily TypeScript, Go and YAML/Kubernetes-manifest development on the macOS workstation, wired through the same bootstrap-module pattern as every other tool in this repo. `config/vim/vimrc` and its exam-parity behavior are untouched.

## Scope

In scope:

- New canonical `config/nvim/` directory (`init.lua` + a handful of `lua/config/*.lua` files), following the "one canonical file per tool" rule at directory granularity.
- New `bootstrap/modules/nvim.sh` module (`nvim_bootstrap`/`_update`/`_verify`), added to the `macos` profile only.
- `~/.config/nvim` symlinked to `config/nvim` via the existing `link_file`/`check_link` pair, backing up whatever is already there (this machine currently has an unmanaged, hand-rolled ~650-line config at `~/.config/nvim`).
- `neovim`, `lua-language-server` and `tree-sitter-cli` added to `bootstrap/profiles/macos.Brewfile`.
- `gopls` installed via `go install`, mirroring `lang.sh`'s existing Go-tooling pattern (Go already ships from the Brewfile on macOS).
- Native LSP wiring (`vim.lsp.config`/`vim.lsp.enable`, Neovim ≥0.11, no `nvim-lspconfig`) for `gopls` (Go), `ts_ls` (TypeScript/JavaScript/TSX), `yamlls` (YAML), `lua_ls` (editing the config itself).
- A minimal, native `vim.pack`-based plugin set (Neovim ≥0.12, which is what brew's current `neovim` formula installs): `nvim-treesitter` (go/gomod/gowork/typescript/tsx/javascript/yaml/json/lua/markdown parsers), `blink.cmp` (completion), `fzf-lua` (fuzzy finder), `gitsigns.nvim`, `which-key.nvim` (key discovery) and `mini.surround` (surround edits). `tree-sitter-cli` joins the Brewfile because nvim-treesitter's `main` branch compiles parsers with it.
- `docs/config.md` gains a "## Neovim" section next to the existing "## Vim" one, plus a `config/nvim/` row in the managed-configuration table. `README.md`'s macOS profile row gains "Neovim" to its "What it gets" list.
- `nvim_verify` checks: the symlink, the Neovim version floor, Brewfile formulae present (via `brew bundle check`), `gopls` on `PATH`, and a headless load smoke test (`nvim --headless -u config/nvim/init.lua -c 'qa'` exits 0).

Out of scope (explicitly excluded):

- Any change to `config/vim/vimrc`, its symlink, or CKA/RHCSA/CKS exam-parity behavior. Vim stays the exam-parity editor; this feature never touches it.
- Linux lab profiles (`rhel`, `ubuntu`, `proxmox`) — Neovim stays macOS-only. Lab hosts keep vanilla vim, by construction (the module is only added to `macos.sh`'s `MODULES`), not just by convention.
- Mason or any in-editor package manager. Language servers are installed by the bootstrap module / brew / `go install`, the same way this repo already manages every other tool.
- Managing Node.js/npm itself — an earlier `nvm` marker block was deliberately removed from this repo (see the legacy-block list in `bootstrap/lib/common.sh`). `typescript-language-server` and `yaml-language-server` (both npm-distributed) are installed by the module only when `npm` is already on `PATH`; otherwise the module reports `na` with a one-line prerequisite note, and `nvim_verify` reports the same servers as `warn`, never `bad`.
- Debugging (DAP), a file-tree plugin, a dashboard/start screen, a formatter/linter plugin, or any plugin not in the six-plugin list above. A personal, unmanaged `lua/user/init.lua` extension point (parallel to vimrc's `~/.vimrc.local`) is provided for local additions; its contents are never part of this repo.
- Format-on-save. Formatting is manual (`vim.lsp.buf.format()` on a keymap), matching this repo's "no surprises" tooling stance (vimrc doesn't auto-format either).

## Acceptance criteria

1. `task bootstrap` (macOS) installs `neovim` and `lua-language-server` via the Brewfile, installs/updates `gopls` via `go install`, and symlinks `~/.config/nvim -> <repo>/config/nvim`, backing up whatever was at `~/.config/nvim` first.
2. `task verify` (macOS) reports `ok` for the symlink, the two new Brewfile formulae, the Neovim version floor, and `gopls`; reports `warn` (not `bad`) for `ts_ls`/`yamlls` when `npm` is absent.
3. Opening a `.go`, `.ts`/`.tsx`, or `.yaml` file in `nvim` attaches the matching LSP client, shows treesitter highlighting, and offers completion via blink.cmp — verified manually, since this is interactive editor UX and not scriptable in CI.
4. `nvim --headless -u config/nvim/init.lua -c 'qa'` exits 0 (no Lua errors on load) — the automatable half of criterion 3.
5. `config/vim/vimrc`, every `bootstrap/modules/*.sh` other than the new `nvim.sh`, and every non-macOS profile file are unchanged (`git diff` shows no changes outside the new/touched files this feature lists).
6. `docs/config.md` documents the new module at the same level of detail as the existing "## Vim" section; `README.md`'s macOS profile row is updated.
7. `task check` (lint, shellcheck, secrets, repo checks) passes with the new module included.

## Source references

- [README.md](../../README.md) §"How it works", §"Profiles", §"Layout" — module/profile conventions this feature follows.
- [docs/config.md](../../docs/config.md) — the managed-configuration table and "## Vim" section this feature parallels.
- [CLAUDE.md](../../CLAUDE.md) — "one canonical file per tool", bash 3.2 constraint, exam-parity rule for vim.
- `bootstrap/modules/shell.sh`, `lang.sh`, `k8s.sh` — existing module patterns for symlinks, opt-in binary installs, and profile-conditional verify.
- Community reference configs surveyed for a "minimal, native, not-a-distribution" Neovim baseline (style/decision input, not vendored code): `nvim-lua/kickstart.nvim`, `wunki/dot-nvim`, `umenorin/minimal-neovim`, `willyelm/config-nvim`, `drone076/tinynvim`, and [`tjdevries/advent-of-nvim`](https://github.com/tjdevries/advent-of-nvim/tree/master/nvim) (leader/clipboard/relativenumber defaults, `TextYankPost` highlight-on-yank autocmd, and the "small number of purpose-named files" shape).

## Edge cases

- A pre-existing, unmanaged `~/.config/nvim` (this machine has one) must be backed up, not merged or deleted — `link_file` already does this for any existing file/dir/symlink at the destination.
- `npm`/Node absent: TS/YAML servers degrade to "not installed" without failing bootstrap or verify.
- Re-running bootstrap must be a no-op (`ok`, not `chg`) the second time, matching this repo's general idempotency expectation — `task test:profiles` itself only covers the Linux containers, so this needs a manual macOS check (documented in `tasks.md`).
- `vim.pack` requires Neovim ≥0.12; `nvim_verify` fails clearly (not silently) if a stale cached formula is older, rather than leaving the user with a config that raises a Lua error on load.

## Open questions

None blocking. Plugin-manager and LSP-wiring choices are design decisions recorded in `plan.md`, not requirements needing separate sign-off.

## Approval

Status: **approved**. Approver: nawodyaishan (chat, 2026-09-30). Scope covered: this revision of `spec.md`, `plan.md` and `tasks.md` as drafted 2026-09-30. Authorization to implement both batches, including the real (non-`--dry-run`) `bootstrap --profile macos` run needed for Batch 2's idempotency check, was given in the same message.

Amendment 2026-10-01: plugin set grew from four to six (`which-key.nvim`, `mini.surround`), `tree-sitter-cli` added to the Brewfile, and the config adopted native-option, diagnostics, LspAttach, fzf-lua LSP picker and gitsigns-keymap improvements after comparison with `nvim-lua/kickstart.nvim`. Approver: nawodyaishan (chat, 2026-10-01, "go ahead" to the stated plan). Mason, Telescope, conform and format-on-save remain excluded.
