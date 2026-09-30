# Managed configuration

Each tool has exactly one canonical file, shared by every machine.

| File | Installed as | Notes |
|---|---|---|
| [shell/aliases.sh](../config/shell/aliases.sh) | sourced by bashrc/zshrc | The only aliases file. Optional tools are guarded with `command -v`; nothing shadows a standard command or auto-approves anything destructive. |
| [shell/functions.sh](../config/shell/functions.sh) | sourced by bashrc/zshrc | `mkcd`, `kns`, `ports`, `wbpath`. |
| [shell/bashrc](../config/shell/bashrc), [shell/zshrc](../config/shell/zshrc) | one marker block in `~/.bashrc` (Linux) or `~/.zshrc` (Mac) | History, editors, PATH, nvm, kubectl completion for `k`. |
| [tmux/tmux.conf](../config/tmux/tmux.conf) | `~/.tmux.conf` symlink | Stock keys, plugin-free, tmux 3.2+. |
| [vim/vimrc](../config/vim/vimrc) | `~/.vimrc` symlink | Small and YAML-safe. Sources `~/.vimrc.local` for personal plugins or themes. |
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

## tmux

Keys stay stock on purpose: prefix `Ctrl-b`, `%`/`"` splits, default copy mode. That way muscle memory matches a fresh lab node or an exam terminal. The config adds mouse support, OSC 52 clipboard copying (copy-mode selections reach the Mac clipboard even over SSH), a 100k scrollback, a Catppuccin Mocha status bar matching Ghostty, and a per-host accent (mauve locally, green over SSH). The status glyphs need a Nerd Font on the Mac terminal. Nothing needs installing on the remote.

## Vim

Vim stops loading `defaults.vim` when `~/.vimrc` exists, so the vimrc sources it explicitly (guarded for vim-tiny). On top of that it sets two-space expanded indentation, line numbers, smart search, no mouse (so terminal copy/paste keeps working), no swap files, and the Vim 9.1 `comment` package when available.

## Ghostty

The config uses JetBrainsMono Nerd Font with Catppuccin Mocha, a quick terminal on `` ctrl+` ``, and `ssh-terminfo`/`ssh-env` shell integration, so remote vim/tmux render correctly. `window-save-state = always` caches the quick terminal's frame, so a changed `quick-terminal-size` may not apply until that cached state is cleared. Validate with `ghostty +validate-config`; `task lint` does this when Ghostty is installed.
