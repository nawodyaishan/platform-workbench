#!/usr/bin/env bash
# shell: one marker block per rc file, plus tmux/vim/gitconfig symlinks. Sourced by workbench.sh.
# shellcheck disable=SC2034,SC2015

_shell_rc_files() {
  if [ "$WB_OS" = macos ]; then printf '%s\n' "$HOME/.zshrc"; else printf '%s\n' "$HOME/.bashrc"; fi
}
_shell_entry() { if [ "$WB_OS" = macos ]; then echo zshrc; else echo bashrc; fi; }

_shell_block() {
  cat <<BLK
export WORKBENCH_HOME="$WB_ROOT"
[ -r "\$WORKBENCH_HOME/config/shell/$(_shell_entry)" ] && . "\$WORKBENCH_HOME/config/shell/$(_shell_entry)"
BLK
}

_shell_links() { # prints "src dest" pairs
  printf '%s %s\n' "$WB_ROOT/config/tmux/tmux.conf" "$HOME/.tmux.conf"
  printf '%s %s\n' "$WB_ROOT/config/vim/vimrc" "$HOME/.vimrc"
}

shell_bootstrap() {
  hdr "shell wiring"
  local rc s d
  [ -f "$WB_ROOT/config/shell/$(_shell_entry)" ] || die "missing $WB_ROOT/config/shell/$(_shell_entry)"
  for rc in $(_shell_rc_files); do
    legacy_blocks_migrate "$rc"
    marker_block_set "$rc" "" <<< "$(_shell_block)"
  done
  while read -r s d; do link_file "$s" "$d"; done <<< "$(_shell_links)"
  is_dry_run || info "activate now: source $(_shell_rc_files | head -1)"
}

shell_update() { shell_bootstrap; }

shell_verify() {
  hdr "shell wiring (verify)"
  local rc s d
  for rc in $(_shell_rc_files); do
    if marker_block_present "$rc" ""; then
      if [ "$(marker_block_body "$rc" "")" = "$(_shell_block)" ]; then ok "marker block current in $rc"; else bad "marker block in $rc is stale (run bootstrap)"; fi
    else
      bad "no $WB_MARK marker block in $rc"
    fi
    local leg
    leg=$(legacy_blocks_in "$rc" | tr '\n' ',')
    if [ -n "$leg" ]; then bad "legacy marker block(s) remain in $rc: ${leg%,}"; else ok "no legacy marker blocks in $rc"; fi
  done
  while read -r s d; do check_link "$s" "$d"; done <<< "$(_shell_links)"
  # Remote payload from the previous toolkit name; harmless, but no longer used.
  [ ! -d "$HOME/.local/share/ops-workbench" ] || warn "legacy ~/.local/share/ops-workbench remains; remove it once this host verifies clean"
}
