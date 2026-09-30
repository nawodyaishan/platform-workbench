#!/usr/bin/env bash
# Package-manager wrappers for brew, dnf and apt. Sourced only.
# shellcheck disable=SC2034,SC2015


pm_refresh() {
  if is_dry_run; then dry_note "refresh package metadata ($OS_FAMILY)"; return 0; fi
  case "$OS_FAMILY" in
    dnf) $SUDO dnf -q makecache >/dev/null 2>&1 || warn "dnf makecache failed" ;;
    apt) $SUDO apt-get update -qq >/dev/null 2>&1 || warn "apt-get update failed" ;;
    brew) : ;;
  esac
}

pm_installed() { # <pkg>
  case "$OS_FAMILY" in
    dnf) rpm -q --whatprovides "$1" >/dev/null 2>&1 ;;  # curl-minimal provides curl
    apt) dpkg -s "$1" >/dev/null 2>&1 ;;
    brew) brew list --formula "$1" >/dev/null 2>&1 || brew list --cask "$1" >/dev/null 2>&1 ;;
    *) return 1 ;;
  esac
}

_pm_install_raw() {
  case "$OS_FAMILY" in
    dnf) $SUDO dnf install -y -q "$@" ;;
    apt) $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@" ;;
    brew) brew install "$@" ;;
    *) return 1 ;;
  esac
}

# pm_install <pkg>...: install only the missing packages; falls back to one at a time so a
# single unavailable package does not sink the rest.
pm_install() {
  local missing="" p
  for p in "$@"; do pm_installed "$p" || missing="$missing $p"; done
  if [ -z "$missing" ]; then ok "packages present: $*"; return 0; fi
  # shellcheck disable=SC2086
  if is_dry_run; then dry_note "install:$missing"; return 0; fi
  # shellcheck disable=SC2086
  if _pm_install_raw $missing >/dev/null 2>&1; then
    changed "installed:$missing"
    return 0
  fi
  for p in $missing; do
    if _pm_install_raw "$p" >/dev/null 2>&1; then changed "installed $p"; else bad "could not install $p"; fi
  done
}

# pm_check <pkg>...: verify-only.
pm_check() {
  local p
  for p in "$@"; do
    if pm_installed "$p"; then ok "package $p"; else bad "package $p is missing"; fi
  done
}

# pm_upgrade <pkg>...: upgrade only the named, already-installed packages. Never a system upgrade.
pm_upgrade() {
  local inst="" p
  for p in "$@"; do pm_installed "$p" && inst="$inst $p"; done
  [ -n "$inst" ] || { ok "nothing to upgrade"; return 0; }
  # shellcheck disable=SC2086
  if is_dry_run; then dry_note "upgrade:$inst"; return 0; fi
  case "$OS_FAMILY" in
    dnf) # shellcheck disable=SC2086
         $SUDO dnf upgrade -y -q $inst >/dev/null 2>&1 || warn "dnf upgrade reported errors" ;;
    apt) # shellcheck disable=SC2086
         $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --only-upgrade $inst >/dev/null 2>&1 || warn "apt upgrade reported errors" ;;
    brew) # shellcheck disable=SC2086
         brew upgrade $inst >/dev/null 2>&1 || true ;;
  esac
  changed "upgrade attempted:$inst"
}
