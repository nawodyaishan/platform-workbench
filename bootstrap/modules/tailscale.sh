#!/usr/bin/env bash
# tailscale: vendor package repo install (never curl|sh). Login stays interactive.
# shellcheck disable=SC2034,SC2015

_ts_repo() {
  case "$OS_FAMILY" in
    dnf)
      local maj=${OS_VERSION_ID%%.*}
      $SUDO dnf install -y -q dnf-plugins-core >/dev/null 2>&1
      $SUDO dnf config-manager --add-repo "https://pkgs.tailscale.com/stable/rhel/$maj/tailscale.repo" >/dev/null 2>&1 \
        || $SUDO dnf config-manager addrepo --from-repofile="https://pkgs.tailscale.com/stable/rhel/$maj/tailscale.repo" >/dev/null 2>&1
      ;;
    apt)
      local codename distro
      # shellcheck disable=SC1091
      codename=$(. /etc/os-release; echo "${VERSION_CODENAME:-}")
      distro=$OS_ID; [ "$distro" = ubuntu ] || distro=debian
      $SUDO install -d -m 0755 /usr/share/keyrings
      curl -fsSL "https://pkgs.tailscale.com/stable/$distro/$codename.noarmor.gpg" | $SUDO tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
      printf 'deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/%s %s main\n' "$distro" "$codename" \
        | $SUDO tee /etc/apt/sources.list.d/tailscale.list >/dev/null
      $SUDO apt-get update -qq >/dev/null 2>&1
      ;;
  esac
}

tailscale_bootstrap() {
  hdr "tailscale"
  if [ "$WB_OS" = macos ]; then
    if [ -d /Applications/Tailscale.app ] || have tailscale; then ok "Tailscale present (GUI app; log in from the menu bar)"; else warn "install the Tailscale app from the Mac App Store or tailscale.com"; fi
    return 0
  fi
  require_sudo
  if have tailscale; then
    ok "tailscale installed"
  elif is_dry_run; then
    dry_note "add the Tailscale vendor repo and install tailscale"
  else
    _ts_repo || warn "adding the Tailscale repo reported errors"
    pm_install tailscale
  fi
  if have_systemd && ! is_dry_run && have tailscale; then
    $SUDO systemctl enable --now tailscaled >/dev/null 2>&1 && ok "tailscaled enabled" || warn "could not enable tailscaled"
  fi
  info "authenticate interactively: sudo tailscale up   (no auth keys in Git)"
}

tailscale_update() {
  hdr "tailscale (update)"
  if [ "$WB_OS" = macos ]; then na "Tailscale app updates itself"; return 0; fi
  require_sudo; pm_upgrade tailscale
}

tailscale_verify() {
  hdr "tailscale (verify)"
  if [ "$WB_OS" = macos ]; then
    if [ -d /Applications/Tailscale.app ] || have tailscale; then ok "Tailscale present"; else warn "Tailscale not installed"; fi
    return 0
  fi
  if ! have tailscale; then bad "tailscale binary missing"; return 0; fi
  ok "tailscale binary"
  local st self
  if have_systemd; then
    if systemctl is-active --quiet tailscaled; then ok "tailscaled running"; else bad "tailscaled not running"; return 0; fi
  elif ! tailscale status >/dev/null 2>&1; then
    # Same policy as sshd: without systemd (containers) the daemon is not managed here.
    na "no systemd; tailscaled not managed"; return 0
  fi
  if st=$(tailscale status --json 2>/dev/null) && have jq; then
    if [ "$(printf '%s' "$st" | jq -r '.BackendState')" = Running ]; then ok "on the tailnet"; else bad "tailscale not logged in (sudo tailscale up)"; return 0; fi
    self=$(printf '%s' "$st" | jq -r '.Self.HostName')
    if [ -n "${WB_EXPECT_HOST:-}" ]; then
      if [ "$self" = "$WB_EXPECT_HOST" ]; then ok "tailnet hostname is $self"; else bad "tailnet hostname is '$self', expected '$WB_EXPECT_HOST'"; fi
    else
      kv "hostname" "$self"
    fi
  else
    bad "tailscale status unavailable"
  fi
}
