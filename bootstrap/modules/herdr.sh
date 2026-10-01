#!/usr/bin/env bash
# herdr: optional tmux alternative. Only the config is linked; the binary is never installed
# here. macOS only, like the nvim module.
# shellcheck disable=SC2034,SC2015

_herdr_link() { printf '%s %s\n' "$WB_ROOT/config/herdr/config.toml" "$HOME/.config/herdr/config.toml"; }

herdr_bootstrap() {
  hdr "herdr"
  if [ "$WB_OS" != macos ]; then na "herdr module is macOS only"; return 0; fi
  local s d
  read -r s d <<< "$(_herdr_link)"
  link_file "$s" "$d"
  have herdr || na "herdr not installed (optional): brew install herdr"
}

herdr_update() {
  hdr "herdr (update)"
  if [ "$WB_OS" != macos ]; then na "herdr module is macOS only"; return 0; fi
  local s d
  read -r s d <<< "$(_herdr_link)"
  link_file "$s" "$d"
}

herdr_verify() {
  hdr "herdr (verify)"
  if [ "$WB_OS" != macos ]; then na "herdr module is macOS only"; return 0; fi
  local s d
  read -r s d <<< "$(_herdr_link)"
  check_link "$s" "$d"
  if have herdr; then
    if HERDR_CONFIG_PATH="$s" herdr config check >/dev/null 2>&1; then ok "herdr config check"
    else bad "herdr config check reported issues"; fi
  else
    na "herdr not installed (optional): brew install herdr"
  fi
}
