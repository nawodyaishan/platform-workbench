# Managed configuration

Each tool has exactly one canonical file, shared by every machine.

| File | Installed as | Notes |
|---|---|---|
| [shell/aliases.sh](../config/shell/aliases.sh) | sourced by bashrc/zshrc | The only aliases file. Optional tools are guarded with `command -v`; nothing shadows a standard command or auto-approves anything destructive. |
| [shell/functions.sh](../config/shell/functions.sh) | sourced by bashrc/zshrc | `mkcd`, `kns`, `ports`, `wbpath`, `up [n]`, `clonecd <url>`. |
| [shell/bashrc](../config/shell/bashrc), [shell/zshrc](../config/shell/zshrc) | one marker block in `~/.bashrc` (Linux) or `~/.zshrc` (Mac) | History, editors, PATH, nvm, kubectl completion for `k`. |
| [tmux/tmux.conf](../config/tmux/tmux.conf) | `~/.tmux.conf` symlink | Prefix `Ctrl-b`, Vim copy mode, plugin-free, tmux 3.2+. |
| [herdr/config.toml](../config/herdr/config.toml) | `~/.config/herdr/config.toml` symlink (macOS) | Optional tmux alternative: `Ctrl-b` prefix, catppuccin. |
| [vim/vimrc](../config/vim/vimrc) | `~/.vimrc` symlink | Small and YAML-safe. Sources `~/.vimrc.local` for personal plugins or themes. |
| [nvim/](../config/nvim/) | `~/.config/nvim` symlink | Mac only; minimal daily-driver for Go/TypeScript/YAML. See below. |
| [git/gitconfig](../config/git/gitconfig) | `include.path` in `~/.gitconfig` | Defaults only, no identity. |
| [ssh/workbench.conf](../config/ssh/workbench.conf) | `~/.ssh/config.d/50-workbench.conf` symlink | Mac only; see [ssh.md](ssh.md). |
| [ghostty/config.ghostty](../config/ghostty/config.ghostty) | not linked | Mac only. Point Ghostty at it with `config-file = …` or copy it. |

The marker block written into your rc file looks like this, and bootstrap owns only the lines between the markers:

```bash
# >>> platform-workbench >>>
export WORKBENCH_HOME="/path/to/platform-workbench"
[ -r "$WORKBENCH_HOME/config/shell/zshrc" ] && . "$WORKBENCH_HOME/config/shell/zshrc"
# <<< platform-workbench <<<
```

On zsh the block is appended last, so it loads after oh-my-zsh and its definitions win. Keep local secrets and host-specific values in your own rc file outside the block.

## Aliases without bootstrap

To get just the aliases and functions on a machine without running bootstrap (a borrowed laptop, a lab VM, a container), generate a paste-in installer:

```bash
task aliases                          # Mac: copies it to the clipboard
scripts/aliases-snippet.sh > aliases-install.txt   # anywhere: save it instead
```

Paste it into any bash or zsh prompt, including over SSH, or run it with `sh aliases-install.txt`. It:

- picks `~/.zshrc` for zsh, `~/.bashrc` for bash on Linux, or `~/.bash_profile` for bash on macOS. Run `export PW_RC=<file>` first to choose another file;
- backs the file up to `<file>.pw-backup.<timestamp>`;
- writes the contents of `aliases.sh` and `functions.sh` between `# >>> platform-workbench aliases >>>` markers, replacing the block in place when you paste a newer version;
- does nothing if the file already loads platform-workbench through bootstrap.

Run `. ~/.zshrc` (or open a new shell) to load it. To remove it, delete the marker block. The snippet is generated from the canonical files each time, so nothing is duplicated in the repository, and `task lint` checks it stays idempotent.

The installer is wrapped in `/bin/sh -s <<'…'` because zsh rejects pasted `#` comment lines unless `INTERACTIVE_COMMENTS` is set.

## Alias conventions

Aliases follow how the workbench is actually used day to day: `make` targets (`m`, `mr`, `ml`, `mb`), `task` (`t`), Git, kubectl, Terraform workspaces and state, Docker Compose, Homebrew, tmux (`tm` attaches or creates `main`) and resuming AI coding CLI sessions (`clr`, `clc`, `cxr`, `gmr`). A few rules keep them predictable:

- Names that oh-my-zsh's `git`, `kubectl`, `terraform` and `docker` plugins also define keep the oh-my-zsh meaning, so an alias behaves the same in bash and zsh.
- `tfa` and `tfd` always prompt. There is no auto-approve alias, and no alias for publishing targets such as `make release`; `m release` is short enough.
- `bu` runs `brew update && brew outdated`, so upgrading stays a separate, deliberate step.
- Nothing shadows a standard command, so `ls`, `cat` and `df` keep their stock behaviour. Personal replacements such as `ls=eza` belong in your own rc file.

## tmux

The main multiplexer. Launch with `tm` (`tmux new-session -A -s main`). Prefix is `Ctrl-b`; `Ctrl-b Ctrl-b` sends a literal `Ctrl-b` to the program (Vim page-up). Stock keys stay (`c n p w d [ z x %`, `"`, arrows, `0`-`9` window jumps), and the config adds `h/j/k/l` pane focus, `|` and `-` splits, and `R` to reload. All splits and new windows open in the current pane's directory. Windows and panes number from 1. Copy mode is Vim style: `v` selects, `y` copies, `Ctrl-v` toggles a rectangle. Escape time is 50 ms, history 100k lines, focus events on, mouse on (everything also works from the keyboard).

Clipboard is OSC 52 only (`set-clipboard on`, no `pbcopy`/`xclip`): Ghostty writes the local clipboard, on the Mac and over SSH alike. Colours use `tmux-256color` (falling back to `screen-256color`) plus `terminal-features` for RGB; `TERM` is never overridden in shell startup files. The status bar (Catppuccin Mocha, per-host accent: mauve locally, green over SSH) shows session, windows, host, date and time; the glyphs need a Nerd Font on the Mac terminal. No bindings exist outside the prefix, so Ghostty, shells, Vim and Neovim keep every normal key.

Reload: `Ctrl-b R`, or `tmux source-file ~/.tmux.conf`. Existing sessions keep the old prefix until reloaded.

## Herdr (optional)

Herdr is a separate multiplexer, not a tmux layer. Launch it on its own with `herdr`; launch tmux with `tm`. Do not run one inside the other (`allow_nested = false`). Install with `brew install herdr` (or `curl -fsSL https://herdr.dev/install.sh | sh`); the workbench only links the config. Validate with `herdr config check`; reload a running server with `herdr server reload-config` or `Ctrl-b Shift-R`.

The config sets only the prefix, the `catppuccin` theme, `|` as an extra side-by-side split, in-app toasts for background agents and symbol status indicators; everything else is Herdr's default. Option+Left/Right word jumps inside Herdr panes (for example the Claude Code prompt) rely on the Ghostty config unbinding Ghostty's default `esc:b`/`esc:f` for those keys, with a matching zsh `bindkey` in `config/shell/zshrc`. Agent visibility is the sidebar (`Ctrl-b b` toggles it), workspaces are `Ctrl-b w` / `Ctrl-b g`.

| Action | tmux | Herdr |
|---|---|---|
| Prefix | `Ctrl-b` | `Ctrl-b` |
| Pane focus | `h/j/k/l` | `h/j/k/l` |
| Split side-by-side / stacked | `\|` / `-` | `\|` or `v` / `-` |
| New window / tab | `c` | `c` |
| Next / previous | `n` / `p` | `n` / `p` |
| Zoom, close pane | `z`, `x` | `z`, `x` |
| Copy mode | `[`, `v` select, `y` copy | `[`, `v` select, `y` copy |
| **Detach** | **`d`** | **`q`** |
| Workspace / session picker | `w`, `s` | `w`, `g` |
| Reload config | `R` | `Shift-R` |

## Vim

Vim stops loading `defaults.vim` when `~/.vimrc` exists, so the vimrc sources it explicitly (guarded for vim-tiny). On top of that it sets two-space expanded indentation, line numbers, smart search, no mouse (so terminal copy/paste keeps working), no swap files, and the Vim 9.1 `comment` package when available.

## Neovim

Separate from Vim on purpose: Vim ([above](#vim)) stays stock so muscle memory matches a CKA/RHCSA/CKS exam terminal, and Neovim carries the daily-driver setup instead. Native only — no plugin manager to bootstrap (Neovim 0.12+'s built-in `vim.pack`), no `nvim-lspconfig` (native `vim.lsp.config`/`vim.lsp.enable`), no Mason. Language servers come from the same install paths this toolkit already uses elsewhere: `gopls` via `go install`, `typescript-language-server`/`yaml-language-server` via `npm install -g`, `lua-language-server` from the Brewfile; each LSP only enables itself if its binary is on `PATH`, so a machine missing Node or Go just gets fewer servers, not an error. Six plugins: `nvim-treesitter` (its `main` branch compiles parsers with the `tree-sitter` CLI, which the Brewfile installs; a `PackChanged` hook runs `:TSUpdate` after updates), `blink.cmp` (pinned to its `v1` line — `main` is an in-development v2 needing a separate `blink.lib` package), `fzf-lua`, `gitsigns.nvim`, `which-key.nvim` (shows pending `<leader>` keys) and `mini.surround` (`sa`/`sd`/`sr`). `lua/user/init.lua` (untracked, `.gitignore`d) is the escape hatch for personal additions, mirroring `~/.vimrc.local`.

Keys (leader is `Space`; which-key lists the rest as you type): `<leader>ff`/`fg`/`fw`/`fb`/`fr`/`fo`/`fk`/`fh`/`fd` fzf-lua pickers, `<leader><leader>` buffers, `<leader>/` search the buffer; `grr`/`gri`/`grt`/`gO`/`gW` LSP pickers once a server attaches; `<leader>cf` formats (manual, never on save), `<leader>th` toggles inlay hints; `]d`/`[d` jump diagnostics and show the message, `<leader>e`/`q` float and location list; `]c`/`[c` and `<leader>h*` git hunks; `<C-h/j/k/l>` window focus; `<Esc>` clears search highlight. Formatting sits under `<leader>c` so no bare `<leader>f` makes the `<leader>f*` pickers wait for a second key.

## Ghostty

The config uses JetBrainsMono Nerd Font with Catppuccin Mocha, a quick terminal on `` ctrl+` ``, and `ssh-terminfo`/`ssh-env` shell integration, so remote vim/tmux render correctly. `window-save-state = always` caches the quick terminal's frame, so a changed `quick-terminal-size` may not apply until that cached state is cleared. Validate with `ghostty +validate-config`; `task lint` does this when Ghostty is installed.
