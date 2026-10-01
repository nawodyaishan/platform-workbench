# Tasks: Neovim minimal config

Reads `spec.md` and `plan.md` (both drafted 2026-09-30). Specialist/tool assignment: none beyond `plan.md`'s "no additional specialist needed" — no task-specific exceptions.

## Task list

| ID | Task | Depends on | Verification |
|---|---|---|---|
| T1 | Write `config/nvim/init.lua` and `config/nvim/lua/config/options.lua`: leader/clipboard/relativenumber/YAML two-space indent (mirroring `config/vim/vimrc`'s YAML block), `retrobox` colorscheme, `TextYankPost` highlight-on-yank autocmd, `pcall(require, "user")` escape hatch. | — | `nvim --headless -u config/nvim/init.lua -c 'qa'` exits 0 |
| T2 | Write `config/nvim/lua/config/pack.lua` (`vim.pack.add` for `nvim-treesitter`, `blink.cmp`, `fzf-lua`, `gitsigns.nvim`) and `config/nvim/lua/config/treesitter.lua` (`ensure_installed` limited to go/gomod/gowork/typescript/tsx/javascript/json/yaml/lua/markdown, `highlight.enable = true`). | T1 | Same headless smoke test; `:checkhealth nvim-treesitter` reviewed manually |
| T3 | Write `config/nvim/lua/config/lsp.lua` (`vim.lsp.config`/`vim.lsp.enable` for `gopls`, `ts_ls`, `yamlls`, `lua_ls`) and `config/nvim/lua/config/keymaps.lua` (manual `vim.lsp.buf.format()` keymap, `fzf-lua` picker keymaps, `gitsigns` hunk keymaps). | T1 | Same headless smoke test; manual open-a-`.go`/`.ts`/`.yaml`-file check per spec acceptance criterion 3 |
| T4 | Write `bootstrap/modules/nvim.sh`: `nvim_bootstrap` (`go install gopls`, conditional `npm install -g typescript-language-server yaml-language-server` when `have npm`, `link_file "$WB_ROOT/config/nvim" "$HOME/.config/nvim"`), `nvim_update` (re-run `go install`/`npm install -g` for upgrades), `nvim_verify` (`check_link`, `have nvim` + version ≥0.12, `have gopls`, `have ts_ls`/`have yaml-language-server` as `warn` not `bad`, headless smoke test). | T1–T3 | `bash -n bootstrap/modules/nvim.sh`; `shellcheck bootstrap/modules/nvim.sh` |
| T5 | Add `neovim` and `lua-language-server` to `bootstrap/profiles/macos.Brewfile`; add `nvim` to `MODULES` in `bootstrap/profiles/macos.sh`. Confirm no other profile file changes. | T4 | `bootstrap/workbench.sh bootstrap --profile macos --dry-run` shows the new module's planned brew/link actions; `git diff --stat` touches only the listed files |
| T6 | Update `docs/config.md`: new "## Neovim" section (parallel structure to "## Vim") and a `config/nvim/` row in the managed-configuration table. | T1–T5 | Markdown link check (part of `task check`'s repo checks) |
| T7 | Update `README.md`'s macOS profile row ("What it gets") to include Neovim. | T5 | Visual diff review; `task check` |
| T8 | Run `task check` end to end; fix any lint/shellcheck/secrets/repo findings. Manually verify idempotency: `bootstrap/workbench.sh bootstrap --profile macos` twice in a row reports `ok`, not `chg`, on the second run for everything this feature added (needs execution authorization — see Batch 1 note). | T1–T7 | `task check` exit 0; recorded manual idempotency result |

## Batches

### Batch 1 — core module and config

- Tasks: T1, T2, T3, T4, T5
- Outcome: `config/nvim/` exists and loads cleanly headless; `bootstrap/modules/nvim.sh` exists with all three lifecycle functions; the `macos` profile wires it in; no other profile or `config/vim/` file changed.
- Verification: T1–T5's individual checks, plus `git diff --stat` scoped to the expected file list, plus the macOS `--dry-run` bootstrap output.
- State: **complete**
- Next action: none. T1–T3 verified via headless smoke test (`nvim --headless --cmd "set rtp^=$PWD/config/nvim" -u "$PWD/config/nvim/init.lua" -c 'qa'`, exit 0, after fixing an unplanned `blink.cmp` v2/`blink.lib` issue — see note below). T4/T5 verified via `bash -n`, `shellcheck`, and a `--dry-run` bootstrap showing the new module's planned actions.

### Batch 2 — docs and final verification

- Tasks: T6, T7, T8
- Outcome: `docs/config.md` and `README.md` describe the new module at parity with the existing Vim documentation; `task check` passes; idempotency is confirmed manually.
- Verification: T6–T8's individual checks.
- State: **T6, T7 complete; T8 partially complete**
- Next action: `task check` passes end to end (T8's first half). The real, non-`--dry-run` `bootstrap --profile macos` run was attempted and blocked by this session's auto-mode permission classifier as a real-machine mutating action, despite the standing authorization recorded below. It needs to be run directly by the user (or re-attempted with explicit interactive approval) to confirm idempotency.

Implementation note (not a scope change, so no re-approval needed): `blink.cmp` installed via `vim.pack.add` with no version pin resolves to its `main` branch, which is an in-development "v2" with a new hard dependency on a separate `saghen/blink.lib` plugin not in this feature's plugin list. Fixed by pinning `config/nvim/lua/config/pack.lua`'s `blink.cmp` entry to `version = "v1"` (the literal branch name — a `vim.version.range("1.*")` semver constraint was tried first and did not work, seemingly because a stale `nvim-pack-lock.json` from an earlier unpinned test run was overriding the version field; clearing that lockfile alongside the pin fixed it). Also added `config/nvim/lua/user/` and `config/nvim/nvim-pack-lock.json` to `.gitignore`: the former is the personal-overrides escape hatch `init.lua` already `pcall(require)`s, the latter is `vim.pack`'s auto-generated lockfile, written directly into `config/nvim/` once `~/.config/nvim` is symlinked into the repo — neither belongs in a shared, multi-machine public repo.

Note: T8's real `bootstrap --profile macos` run (not `--dry-run`) installs brew formulae, runs `go install`/`npm install -g`, and symlinks `~/.config/nvim` on this actual machine — a real-machine action per this repo's rule requiring explicit human authorization every time, separate from the combined spec/plan/tasks approval below.

## Approval and continuation

Combined approval for `spec.md` + `plan.md` + `tasks.md` (this revision set, drafted 2026-09-30) is recorded in `spec.md`'s "## Approval" section. Status: **approved** (nawodyaishan, chat, 2026-09-30), including authorization for T8's real bootstrap run.

Continuation state: Batch 1 complete. Batch 2's docs updates (T6, T7) and `task check` (first half of T8) are complete. The only remaining step is the real `bootstrap --profile macos` run (twice, to confirm idempotency), which needs the user to run it directly — the session's auto-mode classifier blocked the agent from running it despite the recorded authorization.

### Amendment batch — 2026-10-01 (kickstart comparison)

- Tasks: Lua config refresh (options, diagnostics, LspAttach, fzf-lua LSP pickers, gitsigns `on_attach`, `PackChanged`, generic treesitter loader, which-key, mini.surround), `tree-sitter-cli` in the Brewfile and `nvim_verify`, docs/spec/plan updates.
- State: **complete**. `task check` passes; headless load exits 0. With `tree-sitter-cli` installed (2026-10-01) parsers compile, treesitter highlighting is active on a `.go` buffer, gopls attaches, `]d` opens the diagnostic float, and `saiw)` surrounds. Interactive fzf-lua pickers and which-key popups are still only checked by registration, not by eye.
