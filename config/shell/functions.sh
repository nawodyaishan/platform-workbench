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
