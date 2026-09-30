#!/usr/bin/env bash
# git: include the repo gitconfig and verify identity. Sourced by workbench.sh.
# shellcheck disable=SC2034,SC2015
# Identity (user.name/email) is never invented or prompted for; it is only checked.

_git_inc() { echo "$WB_ROOT/config/git/gitconfig"; }

# Includes left behind by the toolkit's previous name (the ops-workbench checkout).
_git_legacy_incs() { git config --global --get-all include.path 2>/dev/null | grep '/ops-workbench/config/git/gitconfig$' || true; }

_git_legacy_migrate() {
  local inc
  while IFS= read -r inc; do
    [ -n "$inc" ] || continue
    if is_dry_run; then dry_note "remove legacy git include $inc"; continue; fi
    backup_copy "$HOME/.gitconfig"
    git config --global --fixed-value --unset include.path "$inc" && changed "removed legacy git include $inc"
  done <<< "$(_git_legacy_incs)"
}

git_bootstrap() {
  hdr "git"
  if ! have git; then
    if is_dry_run; then dry_note "include $(_git_inc) once git is installed"; else bad "git is not installed (base module)"; fi
    return 0
  fi
  if git config --global --get-all include.path 2>/dev/null | grep -Fxq "$(_git_inc)"; then
    ok "gitconfig include present"
  elif is_dry_run; then
    dry_note "git config --global --add include.path $(_git_inc)"
  else
    backup_copy "$HOME/.gitconfig"
    git config --global --add include.path "$(_git_inc)"
    changed "included $(_git_inc) from ~/.gitconfig"
  fi
  _git_legacy_migrate
}

git_update() { git_bootstrap; }

git_verify() {
  hdr "git (verify)"
  have git || { bad "git is not installed"; return 0; }
  if git config --global --get-all include.path 2>/dev/null | grep -Fxq "$(_git_inc)"; then ok "gitconfig include"; else bad "gitconfig include missing"; fi
  if [ -n "$(_git_legacy_incs)" ]; then bad "legacy ops-workbench git include remains (run bootstrap)"; fi
  if [ -n "$(git config --global user.name 2>/dev/null)" ] && [ -n "$(git config --global user.email 2>/dev/null)" ]; then
    ok "git identity set"
  else
    warn "git user.name/user.email not set (git config --global user.name ...)"
  fi
}
