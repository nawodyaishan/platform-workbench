# shellcheck shell=sh
# platform-workbench canonical shell functions. Sourced by bash and zsh.
# No secrets and no host-specific values.

# mkdir -p and cd into it.
mkcd() {
  [ -n "$1" ] || { echo "usage: mkcd <dir>" >&2; return 1; }
  mkdir -p -- "$1" && cd -- "$1" || return
}

# Switch the current kubectl context's namespace.
kns() {
  [ -n "$1" ] || { echo "usage: kns <namespace>" >&2; return 1; }
  kubectl config set-context --current --namespace="$1"
}

# Listening TCP/UDP sockets.
ports() {
  if command -v ss >/dev/null 2>&1; then
    ss -tulpn
  else
    lsof -nP -iTCP -sTCP:LISTEN
  fi
}

# Print PATH one entry per line.
wbpath() {
  printf '%s\n' "$PATH" | tr ':' '\n'
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

# git clone, then cd into the new checkout.
clonecd() {
  [ -n "$1" ] || { echo "usage: clonecd <url> [dir]" >&2; return 1; }
  _d=${2:-$(basename -- "$1" .git)}
  git clone -- "$1" "$_d" && cd -- "$_d" || { unset _d; return 1; }
  unset _d
}
