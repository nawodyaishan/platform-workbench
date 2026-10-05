#!/usr/bin/env bash
# lang: opt-in Go and Node (--extras go,node). Off by default on Linux; Go comes from the Brewfile on macOS.
# shellcheck disable=SC2034,SC2015

lang_bootstrap() {
  hdr "languages"
  if [ "$WB_OS" = macos ]; then ok "Go comes from the Brewfile"; return 0; fi
  if extra_on go; then
    if [ -x /usr/local/go/bin/go ] && /usr/local/go/bin/go version | grep -q "go$GO_VERSION "; then ok "go $GO_VERSION"
    elif is_dry_run; then dry_note "install go $GO_VERSION (checksum-verified tarball)"
    else require_sudo; go_install_tarball "$GO_VERSION"; fi
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
