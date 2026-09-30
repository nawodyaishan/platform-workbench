#!/usr/bin/env bash
# ssh: Linux sshd service and Mac OpenSSH client aliases.
# shellcheck disable=SC2034,SC2015

_sshd_unit() { if systemctl list-unit-files 2>/dev/null | grep -q '^sshd\.service'; then echo sshd; else echo ssh; fi; }

_ssh_mac_bootstrap() {
  local dir="$HOME/.ssh" local_conf="$HOME/.ssh/config.d/10-hosts.local.conf"
  if is_dry_run; then
    [ -d "$dir/cm" ] || dry_note "create $dir/cm (mode 700)"
    [ -f "$local_conf" ] || dry_note "copy hosts.local.conf.example to $local_conf"
  else
    mkdir -p "$dir/config.d" "$dir/cm"
    chmod 700 "$dir" "$dir/config.d" "$dir/cm"
    if [ ! -e "$local_conf" ]; then
      cp "$WB_ROOT/config/ssh/hosts.local.conf.example" "$local_conf"
      chmod 600 "$local_conf"
      changed "created $local_conf"
    fi
  fi
  link_file "$WB_ROOT/config/ssh/workbench.conf" "$dir/config.d/50-workbench.conf"
  legacy_blocks_migrate "$dir/config"
  marker_block_set "$dir/config" ssh --top <<< 'Include ~/.ssh/config.d/*.conf'
}

_ssh_mac_verify() {
  local dir="$HOME/.ssh" host value
  check_link "$WB_ROOT/config/ssh/workbench.conf" "$dir/config.d/50-workbench.conf"
  if [ -f "$dir/config" ] && [ "$(sed -n '1p' "$dir/config")" = "$(_mb_start ssh)" ]; then
    ok "SSH Include block at top"
  else bad "SSH Include block missing from top of $dir/config"; fi
  if [ "$(marker_block_body "$dir/config" ssh 2>/dev/null)" = 'Include ~/.ssh/config.d/*.conf' ]; then
    ok "SSH Include current"
  else bad "SSH Include is stale"; fi
  [ -f "$dir/config.d/10-hosts.local.conf" ] && ok "local SSH overrides present" || bad "local SSH overrides missing"
  [ -d "$dir/cm" ] && [ "$(stat -f %Lp "$dir/cm")" = 700 ] && ok "SSH control directory mode 700" || bad "SSH control directory missing or unsafe mode"
  for host in $(hosts_list); do
    if ! value=$(ssh -G -F "$dir/config" "$host" 2>/dev/null); then bad "ssh -G $host failed"; continue; fi
    printf '%s\n' "$value" | grep -q '^forwardagent no$' && ok "$host agent forwarding off" || bad "$host agent forwarding is enabled"
    printf '%s\n' "$value" | grep -q '^serveraliveinterval 30$' && ok "$host keepalive" || bad "$host keepalive differs"
    printf '%s\n' "$value" | grep -q '/.ssh/cm/' && ok "$host control path" || bad "$host control path differs"
  done
  if grep -Ei '^[[:space:]]*(ForwardAgent[[:space:]]+yes|StrictHostKeyChecking[[:space:]]+no)' "$dir/config" "$dir/config.d/"*.conf 2>/dev/null; then
    bad "unsafe SSH setting present"
  else ok "no unsafe SSH setting"; fi
  if [ -n "$(legacy_blocks_in "$dir/config")" ]; then bad "legacy marker block remains in $dir/config (run bootstrap)"; fi
}

ssh_bootstrap() {
  hdr "ssh"
  if [ "$WB_OS" = macos ]; then _ssh_mac_bootstrap; return 0; fi
  if [ "$WB_PROFILE" != proxmox ]; then require_sudo; pm_install openssh-server; fi
  if ! have_systemd; then na "no systemd; sshd not managed"; return 0; fi
  local u; u=$(_sshd_unit)
  if systemctl is-active --quiet "$u" && systemctl is-enabled --quiet "$u" 2>/dev/null; then
    ok "$u active and enabled"
  elif is_dry_run; then
    dry_note "systemctl enable --now $u"
  else
    require_sudo
    if $SUDO systemctl enable --now "$u" >/dev/null 2>&1; then changed "enabled $u"; else bad "could not enable $u"; fi
  fi
  info "password auth is left untouched; add your public key to ~/.ssh/authorized_keys yourself"
}

ssh_update() {
  if [ "$WB_OS" = macos ]; then hdr "ssh (update)"; _ssh_mac_bootstrap; return 0; fi
  if [ "$WB_PROFILE" != proxmox ]; then hdr "ssh (update)"; pm_upgrade openssh-server; fi
  ssh_bootstrap
}

ssh_verify() {
  hdr "ssh (verify)"
  if [ "$WB_OS" = macos ]; then _ssh_mac_verify; return 0; fi
  if [ "$WB_PROFILE" != proxmox ]; then pm_check openssh-server; fi
  if [ -f "$HOME/.ssh/authorized_keys" ]; then
    if [ "$(stat -c %a "$HOME/.ssh/authorized_keys")" = 600 ]; then ok "authorized_keys mode 600"
    else bad "authorized_keys mode must be 600"; fi
  else warn "authorized_keys absent; key login may not be configured"; fi
  have_systemd || { na "no systemd"; return 0; }
  local u; u=$(_sshd_unit)
  if systemctl is-active --quiet "$u"; then ok "$u running"; else bad "$u not running"; fi
}
