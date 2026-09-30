# Managed configuration

Each tool has exactly one canonical file, shared by every machine.

| File | Installed as | Notes |
|---|---|---|
| [shell/aliases.sh](../config/shell/aliases.sh) | sourced by bashrc/zshrc | The only aliases file. Optional tools are guarded with `command -v`; nothing shadows a standard command or auto-approves anything destructive. |
| [shell/functions.sh](../config/shell/functions.sh) | sourced by bashrc/zshrc | `mkcd`, `kns`, `ports`, `wbpath`, `up [n]`, `clonecd <url>`. |
| [shell/bashrc](../config/shell/bashrc), [shell/zshrc](../config/shell/zshrc) | one marker block in `~/.bashrc` (Linux) or `~/.zshrc` (Mac) | History, editors, PATH, nvm, kubectl completion for `k`. |
| [tmux/tmux.conf](../config/tmux/tmux.conf) | `~/.tmux.conf` symlink | Stock keys, plugin-free, tmux 3.2+. |
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

Keys stay stock on purpose: prefix `Ctrl-b`, `%`/`"` splits, default copy mode. That way muscle memory matches a fresh lab node or an exam terminal. The config adds mouse support, OSC 52 clipboard copying (copy-mode selections reach the Mac clipboard even over SSH), a 100k scrollback, a Catppuccin Mocha status bar matching Ghostty, and a per-host accent (mauve locally, green over SSH). The status glyphs need a Nerd Font on the Mac terminal. Nothing needs installing on the remote.

## Vim

Vim stops loading `defaults.vim` when `~/.vimrc` exists, so the vimrc sources it explicitly (guarded for vim-tiny). On top of that it sets two-space expanded indentation, line numbers, smart search, no mouse (so terminal copy/paste keeps working), no swap files, and the Vim 9.1 `comment` package when available.

## Neovim

Separate from Vim on purpose: Vim ([above](#vim)) stays stock so muscle memory matches a CKA/RHCSA/CKS exam terminal, and Neovim carries the daily-driver setup instead. Native only — no plugin manager to bootstrap (Neovim 0.12+'s built-in `vim.pack`), no `nvim-lspconfig` (native `vim.lsp.config`/`vim.lsp.enable`), no Mason. Language servers come from the same install paths this toolkit already uses elsewhere: `gopls` via `go install`, `typescript-language-server`/`yaml-language-server` via `npm install -g`, `lua-language-server` from the Brewfile; each LSP only enables itself if its binary is on `PATH`, so a machine missing Node or Go just gets fewer servers, not an error. Four plugins: `nvim-treesitter`, `blink.cmp` (pinned to its `v1` line — `main` is an in-development v2 needing a separate `blink.lib` package), `fzf-lua`, `gitsigns.nvim`. `lua/user/init.lua` (untracked, `.gitignore`d) is the escape hatch for personal additions, mirroring `~/.vimrc.local`.

## Ghostty

The config uses JetBrainsMono Nerd Font with Catppuccin Mocha, a quick terminal on `` ctrl+` ``, and `ssh-terminfo`/`ssh-env` shell integration, so remote vim/tmux render correctly. `window-save-state = always` caches the quick terminal's frame, so a changed `quick-terminal-size` may not apply until that cached state is cleared. Validate with `ghostty +validate-config`; `task lint` does this when Ghostty is installed.
