#!/usr/bin/env bash
# nvim: minimal TS/Go/YAML Neovim config, symlinked from config/nvim. macOS only; vim
# (config/vim/vimrc) stays untouched for CKA/RHCSA/CKS exam parity.
# shellcheck disable=SC2034,SC2015

_nvim_link() { printf '%s %s\n' "$WB_ROOT/config/nvim" "$HOME/.config/nvim"; }

_nvim_gopls_install() {
  if ! have go; then na "go missing, skipping gopls"; return 0; fi
  if is_dry_run; then dry_note "go install golang.org/x/tools/gopls@latest"; return 0; fi
  if go install golang.org/x/tools/gopls@latest >/dev/null 2>&1; then changed "installed/updated gopls"
  else warn "gopls install failed"; fi
}

_nvim_npm_servers_install() {
  if ! have npm; then na "npm missing, skipping ts_ls/yamlls"; return 0; fi
  if is_dry_run; then dry_note "npm install -g typescript-language-server typescript yaml-language-server"; return 0; fi
  if npm install -g typescript-language-server typescript yaml-language-server >/dev/null 2>&1; then changed "installed/updated typescript-language-server and yaml-language-server"
  else warn "npm language server install failed"; fi
}

nvim_bootstrap() {
  hdr "neovim"
  if [ "$WB_OS" != macos ]; then na "nvim module is macOS only"; return 0; fi
  local s d
  read -r s d <<< "$(_nvim_link)"
  link_file "$s" "$d"
  _nvim_gopls_install
  _nvim_npm_servers_install
}

nvim_update() {
  hdr "neovim (update)"
  if [ "$WB_OS" != macos ]; then na "nvim module is macOS only"; return 0; fi
  _nvim_gopls_install
  _nvim_npm_servers_install
}

_nvim_version_ge_12() {
  local line major minor
  line=$(nvim --version 2>/dev/null | head -1)
  major=$(printf '%s\n' "$line" | sed -n 's/^NVIM v\([0-9]*\)\..*/\1/p')
  minor=$(printf '%s\n' "$line" | sed -n 's/^NVIM v[0-9]*\.\([0-9]*\).*/\1/p')
  [ -n "$major" ] || return 1
  [ "$major" -gt 0 ] && return 0
  [ -n "$minor" ] && [ "$minor" -ge 12 ]
}

nvim_verify() {
  hdr "neovim (verify)"
  if [ "$WB_OS" != macos ]; then na "nvim module is macOS only"; return 0; fi
  local s d
  read -r s d <<< "$(_nvim_link)"
  check_link "$s" "$d"

  if have nvim && _nvim_version_ge_12; then ok "nvim $(nvim --version | head -1) (>= 0.12, has vim.pack)"
  else bad "nvim missing or older than 0.12"; fi

  have gopls && ok "gopls" || bad "gopls missing"
  have typescript-language-server && ok "typescript-language-server" || warn "typescript-language-server missing (needs npm)"
  have yaml-language-server && ok "yaml-language-server" || warn "yaml-language-server missing (needs npm)"

  if have nvim; then
    if nvim --headless -u "$d/init.lua" -c 'qa' >/dev/null 2>&1; then ok "headless load"
    else bad "headless load failed"; fi
  fi
}
