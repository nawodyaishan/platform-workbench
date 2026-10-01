#!/usr/bin/env bash
# Terraform aliases plus basic Linux helpers for lab VMs.
# Paste into a disposable Linux VM's Bash shell. Session scoped; no installs; writes nothing.
# The basic linux block is identical in every kodekloud/*/*-shell.sh; `task repo` fails if a copy drifts.

# >>> basic linux >>>
export EDITOR=vim
export VIMINIT='set expandtab tabstop=2 shiftwidth=2 softtabstop=2 autoindent number | syntax on'
export LESS='-R -i'

alias c='clear'
alias cl='clear'
alias h='history'
alias ll='ls -laF'
alias la='ls -lAh'
alias ..='cd ..'
alias ...='cd ../..'
alias dfh='df -h'
alias duh='du -sh'
alias psg='ps aux | grep -v grep | grep -i'
alias ty='type -a'
alias mk='man -k'
alias mf='man -f'
alias mw='whereis'
if command -v free >/dev/null 2>&1; then alias mem='free -h'; fi
if command -v lsblk >/dev/null 2>&1; then alias lsb='lsblk'; fi
if command -v ip >/dev/null 2>&1; then
  alias ipa='ip -br address'
  alias ipr='ip route'
fi
if command -v systemctl >/dev/null 2>&1; then
  alias scs='systemctl status'
  alias scf='systemctl --failed'
  alias scl='systemctl list-units --type=service --state=running'
  alias sce='systemctl is-enabled'
fi
if command -v journalctl >/dev/null 2>&1; then
  alias jc='journalctl'
  alias jcf='journalctl -f'
  alias jcu='journalctl -u'
  alias jce='journalctl -p err -b'
fi
if command -v info >/dev/null 2>&1; then alias inf='info'; fi
if command -v tldr >/dev/null 2>&1; then alias tl='tldr'; fi

# mkdir -p and cd into it.
mkcd() {
  [ -n "$1" ] || { echo "usage: mkcd <dir>" >&2; return 1; }
  mkdir -p -- "$1" && cd -- "$1" || return
}

# cd up N directories (default 1): `up 3` is cd ../../..
up() {
  _n=${1:-1}
  case $_n in ''|*[!0-9]*) echo "usage: up [levels]" >&2; unset _n; return 1 ;; esac
  _p=.
  while [ "$_n" -gt 0 ]; do _p=$_p/..; _n=$((_n - 1)); done
  cd -- "$_p" || { unset _n _p; return 1; }
  unset _n _p
}

# Listening TCP/UDP sockets.
ports() {
  if command -v ss >/dev/null 2>&1; then ss -tulpn; else lsof -nP -iTCP -sTCP:LISTEN; fi
}

# Help for one command: builtin -> help, man page -> man, otherwise <cmd> --help.
hlp() {
  [ -n "$1" ] || { echo "usage: hlp <command>" >&2; return 1; }
  case $(type -t "$1" 2>/dev/null) in
    builtin|keyword) help "$1"; return ;;
  esac
  if man -w "$1" >/dev/null 2>&1; then
    man "$1"
  elif command -v "$1" >/dev/null 2>&1; then
    echo "no man page for $1; showing --help" >&2
    "$1" --help 2>&1 | ${PAGER:-less}
  else
    echo "$1: not found" >&2
    return 1
  fi
}

# Search inside a man page: mg <command> <pattern> (2 lines of context, case-insensitive).
mg() {
  [ $# -ge 2 ] || { echo "usage: mg <command> <pattern>" >&2; return 1; }
  MANPAGER=cat PAGER=cat man "$1" 2>/dev/null | { col -bx 2>/dev/null || cat; } | grep -i -C2 -- "$2"
}

# Show the man-page entry for one option: mopt <command> <flag>, e.g. `mopt tar -x`.
mopt() {
  [ $# -ge 2 ] || { echo "usage: mopt <command> <flag>" >&2; return 1; }
  MANPAGER=cat PAGER=cat man "$1" 2>/dev/null | { col -bx 2>/dev/null || cat; } \
    | grep -E -A12 -- "^ +(-[A-Za-z0-9], +)?$2([ ,=<[]|\$)"
}
# <<< basic linux <<<

# --- Terraform (apply/destroy prompt for confirmation, on purpose) ---------------
if command -v terraform >/dev/null 2>&1; then
  alias tf='terraform'
  alias tfi='terraform init'
  alias tfiu='terraform init -upgrade'
  alias tff='terraform fmt'
  alias tffr='terraform fmt -recursive'
  alias tfv='terraform validate'
  alias tfp='terraform plan'
  alias tfpo='terraform plan -out=tfplan'
  alias tfa='terraform apply'
  alias tfd='terraform destroy'
  alias tfo='terraform output'
  alias tfs='terraform state'
  alias tfsl='terraform state list'
  alias tfsh='terraform show'
  alias tfw='terraform workspace'
  alias tfwl='terraform workspace list'
  alias tfws='terraform workspace select'
  alias tfwn='terraform workspace new'
  alias tfpr='terraform providers'
  alias tfg='terraform graph'
  alias tfvr='terraform version'
fi
hostname
if command -v terraform >/dev/null 2>&1; then terraform workspace show 2>/dev/null || true; fi
