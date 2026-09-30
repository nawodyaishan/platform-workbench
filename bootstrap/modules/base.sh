#!/usr/bin/env bash
# base: core CLI packages from the profile arrays. Sourced by workbench.sh.
# shellcheck disable=SC2034,SC2015

_base_pkgs() { printf '%s\n' ${PKGS_BASE[@]+"${PKGS_BASE[@]}"} ${PKGS_NET[@]+"${PKGS_NET[@]}"} ${PKGS_ADMIN[@]+"${PKGS_ADMIN[@]}"}; }

base_bootstrap() {
  hdr "base packages"
  if [ "$WB_OS" = macos ]; then
    have brew || die "Homebrew is required on macOS: https://brew.sh"
    local bf="$WB_ROOT/bootstrap/profiles/macos.Brewfile"
    if is_dry_run; then dry_note "brew bundle --file=$bf"; return 0; fi
    brew bundle --file="$bf" && changed "brew bundle applied" || bad "brew bundle failed"
    return 0
  fi
  require_sudo
  pm_refresh
  # shellcheck disable=SC2046
  pm_install $(_base_pkgs)
}

base_update() {
  hdr "base packages (update)"
  if [ "$WB_OS" = macos ]; then
    if is_dry_run; then dry_note "brew update && brew bundle (upgrade Brewfile formulae only)"; return 0; fi
    brew update >/dev/null 2>&1 || warn "brew update failed"
    brew bundle --file="$WB_ROOT/bootstrap/profiles/macos.Brewfile" && changed "brew bundle applied" || bad "brew bundle failed"
    return 0
  fi
  require_sudo
  pm_refresh
  # shellcheck disable=SC2046
  pm_upgrade $(_base_pkgs)
}

base_verify() {
  hdr "base packages (verify)"
  if [ "$WB_OS" = macos ]; then
    if ! have brew; then bad "Homebrew missing"; return 0; fi
    if brew bundle check --file="$WB_ROOT/bootstrap/profiles/macos.Brewfile" >/dev/null 2>&1; then
      ok "Brewfile satisfied"
    else
      bad "Brewfile not satisfied (run: task bootstrap)"
    fi
    local app
    for app in ${MAC_APPS[@]+"${MAC_APPS[@]}"}; do
      if [ -d "/Applications/$app.app" ]; then ok "app $app"; else warn "app $app not installed (GUI apps are not managed by brew here)"; fi
    done
    return 0
  fi
  # shellcheck disable=SC2046
  pm_check $(_base_pkgs)
}
