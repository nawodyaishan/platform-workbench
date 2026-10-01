#!/usr/bin/env bash
# Kubernetes aliases (superset of cka-shell.sh) plus basic Linux helpers for lab VMs.
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

# --- Kubernetes (superset of cka-shell.sh; same names as config/shell/aliases.sh) --
export KUBE_EDITOR=vim
export do='--dry-run=client -o yaml'
export now='--force --grace-period=0'
if command -v kubectl >/dev/null 2>&1; then
  alias k='kubectl'
  alias kgp='kubectl get pods'
  alias kgpa='kubectl get pods --all-namespaces'
  alias kgpw='kubectl get pods --watch'
  alias kgpwide='kubectl get pods -o wide'
  alias kgs='kubectl get svc'
  alias kgd='kubectl get deploy'
  alias kgn='kubectl get nodes'
  alias kgnw='kubectl get nodes -o wide'
  alias kgns='kubectl get ns'
  alias kga='kubectl get all'
  alias kgi='kubectl get ingress'
  alias kgpvc='kubectl get pvc'
  alias kgcm='kubectl get configmaps'
  alias kgsec='kubectl get secret'
  alias kge='kubectl get events --sort-by=.lastTimestamp'
  alias kaf='kubectl apply -f'
  alias kdf='kubectl delete -f'
  alias kdesc='kubectl describe'
  alias klogs='kubectl logs'
  alias klf='kubectl logs -f'
  alias kexec='kubectl exec -it'
  alias kpf='kubectl port-forward'
  alias ktop='kubectl top pods'
  alias ktopn='kubectl top nodes'
  alias krs='kubectl rollout status'
  alias krh='kubectl rollout history'
  alias kctx='kubectl config current-context'
  alias kctxs='kubectl config get-contexts'
  alias kcuc='kubectl config use-context'
  alias kdry='kubectl --dry-run=client -o yaml'
  if ! type __start_kubectl >/dev/null 2>&1; then
    # shellcheck disable=SC1090
    source <(kubectl completion bash)
  fi
  type __start_kubectl >/dev/null 2>&1 && complete -F __start_kubectl k
fi
if command -v helm >/dev/null 2>&1; then
  alias hm='helm'
  alias hmls='helm list --all-namespaces'
  alias hmi='helm upgrade --install'
  alias hmt='helm template'
  alias hms='helm status'
  alias hmv='helm get values'
  alias hmh='helm history'
fi

# Switch the current kubectl context's namespace.
kns() {
  [ -n "$1" ] || { echo "usage: kns <namespace>" >&2; return 1; }
  kubectl config set-context --current --namespace="$1"
}
hostname
if command -v kubectl >/dev/null 2>&1; then kubectl config current-context; fi
