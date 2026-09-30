#!/usr/bin/env bash
# Host registry helpers (bootstrap/hosts.conf). Sourced only; no dependencies.

WB_HOSTS_FILE="${WB_HOSTS_FILE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/hosts.conf}"

# hosts_list: print each registered alias.
hosts_list() { awk '!/^[[:space:]]*(#|$)/ {print $1}' "$WB_HOSTS_FILE"; }

# host_profile <alias>: print the alias's profile; non-zero when unregistered.
host_profile() {
  local p
  p=$(awk -v h="$1" '!/^[[:space:]]*(#|$)/ && $1==h {print $2; exit}' "$WB_HOSTS_FILE")
  [ -n "$p" ] && printf '%s\n' "$p"
}
