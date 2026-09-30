#!/usr/bin/env bash
# lang: opt-in Go and Node (--extras go,node). Off by default on Linux; Go comes from the Brewfile on macOS.
# shellcheck disable=SC2034,SC2015

_go_install() {
  local ver=$GO_VERSION url sum want
  url="https://go.dev/dl/go$ver.linux-$ARCH.tar.gz"
  want=$(curl -fsSL 'https://go.dev/dl/?mode=json&include=all' | jq -r --arg f "go$ver.linux-$ARCH.tar.gz" '.[].files[] | select(.filename==$f) | .sha256' | head -1)
  [ -n "$want" ] || { bad "could not find a published checksum for go$ver"; return 0; }
  local tmp; tmp=$(mktemp)
  curl -fsSL "$url" -o "$tmp" || { rm -f "$tmp"; bad "download failed: $url"; return 0; }
  sum=$(sha256sum "$tmp" | cut -d' ' -f1)
  if [ "$sum" != "$want" ]; then rm -f "$tmp"; bad "go checksum mismatch"; return 0; fi
  $SUDO rm -rf /usr/local/go && $SUDO tar -C /usr/local -xzf "$tmp" && changed "installed go$ver to /usr/local/go"
  rm -f "$tmp"
}

lang_bootstrap() {
  hdr "languages"
  if [ "$WB_OS" = macos ]; then ok "Go comes from the Brewfile"; return 0; fi
  if extra_on go; then
    if [ -x /usr/local/go/bin/go ] && /usr/local/go/bin/go version | grep -q "go$GO_VERSION "; then ok "go $GO_VERSION"
    elif is_dry_run; then dry_note "install go $GO_VERSION (checksum-verified tarball)"
    else require_sudo; _go_install; fi
  else na "go extra not requested"; fi
  if extra_on node; then require_sudo; pm_install nodejs npm; else na "node extra not requested"; fi
}

lang_update() { lang_bootstrap; }

lang_verify() {
  hdr "languages (verify)"
  if [ "$WB_OS" = macos ]; then have go && ok "go" || bad "go missing"; return 0; fi
  if extra_on go; then [ -x /usr/local/go/bin/go ] && ok "$(/usr/local/go/bin/go version)" || bad "go missing"; else na "go extra not requested"; fi
  if extra_on node; then have node && ok "node $(node --version)" || bad "node missing"; else na "node extra not requested"; fi
}
