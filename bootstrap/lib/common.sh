#!/usr/bin/env bash
# Shared helpers for bootstrap/workbench.sh and its modules. Sourced only.
# shellcheck disable=SC2034,SC2015
# Must run on macOS /bin/bash 3.2: no associative arrays, mapfile or ${var,,}, and
# empty arrays are expanded with the ${arr[@]+"${arr[@]}"} idiom.

# --- Logging and result accounting -----------------------------------------------
N_OK=0; N_WARN=0; N_FAIL=0; N_NA=0; N_CHANGED=0

hdr()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
ok()   { N_OK=$((N_OK + 1));     printf '  ok   %s\n' "$*"; }
warn() { N_WARN=$((N_WARN + 1)); printf '  WARN %s\n' "$*"; }
bad()  { N_FAIL=$((N_FAIL + 1)); printf '  FAIL %s\n' "$*"; }
na()   { N_NA=$((N_NA + 1));     printf '  n/a  %s\n' "$*"; }
info() { printf '       %s\n' "$*"; }
kv()   { printf '  %-15s %s\n' "$1" "$2"; }
die()  { printf '  FAIL %s\n' "$*" >&2; exit 1; }

# changed <msg>: something was modified (or would be, in a dry run).
changed() { N_CHANGED=$((N_CHANGED + 1)); printf '  chg  %s\n' "$*"; }

is_dry_run() { [ "${DRY_RUN:-0}" = "1" ]; }
dry_note()   { N_CHANGED=$((N_CHANGED + 1)); printf '  DRY  would %s\n' "$*"; }

# have <cmd>: command exists on PATH.
have() { command -v "$1" >/dev/null 2>&1; }
# have_systemd: systemd is PID 1 (false in containers, where systemctl exists but cannot work).
have_systemd() { [ -d /run/systemd/system ]; }

# --- Privilege -----------------------------------------------------------------------
# SUDO is empty when already root (or on macOS, which never needs it here).
SUDO=""
init_sudo() {
  if [ "$(id -u)" -eq 0 ] || [ "${WB_OS:-}" = "macos" ]; then SUDO=""; return 0; fi
  have sudo || die "sudo is required for profile '${WB_PROFILE:-?}' but is not installed"
  SUDO="sudo"
}

# require_sudo: fail early, with a clear message, instead of stalling on a hidden prompt.
require_sudo() {
  [ -z "$SUDO" ] && return 0
  is_dry_run && return 0
  sudo -v 2>/dev/null || die "sudo is unavailable or the password was not accepted"
}

# --- Confirmation -----------------------------------------------------------------------
# confirm <prompt> [required-typed-word]: interactive only. WB_YES=1 (--yes) skips the
# plain prompt but never the typed-word prompt. Non-interactive without --yes is a refusal.
confirm() {
  local prompt=$1 word=${2:-} reply
  if [ -z "$word" ] && [ "${WB_YES:-0}" = "1" ]; then return 0; fi
  # A typed word may be piped (tests); a plain y/N prompt needs a terminal.
  if [ -z "$word" ] && [ ! -t 0 ]; then die "confirmation required ('$prompt') but stdin is not a terminal; rerun interactively or pass --yes"; fi
  if [ -n "$word" ]; then
    printf '  %s\n  Type "%s" to continue: ' "$prompt" "$word"
    read -r reply
    [ "$reply" = "$word" ] || die "not confirmed"
  else
    printf '  %s [y/N] ' "$prompt"
    read -r reply
    case "$reply" in y|Y|yes) ;; *) die "not confirmed" ;; esac
  fi
}

# --- Files, links, backups -----------------------------------------------------------------
WB_BACKUP_DIR="${WB_BACKUP_DIR:-$HOME/.platform-workbench-backup/$(date +%Y%m%d-%H%M%S)}"

# backup_path <path>: move an existing file/dir/symlink into the backup dir.
backup_path() {
  local target=$1 rel
  rel=$(printf '%s' "$target" | sed 's#^/##; s#/#_#g')
  mkdir -p "$WB_BACKUP_DIR"
  mv "$target" "$WB_BACKUP_DIR/$rel"
  changed "backed up $target -> $WB_BACKUP_DIR/$rel"
}

# link_file <src> <dest>: idempotent symlink, backing up whatever was there.
link_file() {
  local src=$1 dest=$2
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    ok "linked $dest"
    return 0
  fi
  if is_dry_run; then dry_note "link $dest -> $src"; return 0; fi
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] || [ -L "$dest" ]; then backup_path "$dest"; fi
  ln -s "$src" "$dest"
  changed "linked $dest -> $src"
}

# check_link <src> <dest>: verify-only counterpart of link_file.
check_link() {
  local src=$1 dest=$2
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    ok "$dest -> $src"
  elif [ -e "$dest" ] || [ -L "$dest" ]; then
    bad "$dest exists but does not point at $src"
  else
    bad "$dest is missing"
  fi
}

# --- Marker blocks ---------------------------------------------------------------------------
# Blocks look like:  # >>> platform-workbench[ <name>] >>>  ...  # <<< platform-workbench[ <name>] <<<
# The optional trailing <mark> argument addresses blocks written under an older prefix.
WB_MARK=platform-workbench
_mb_start() { printf '# >>> %s%s >>>' "${2:-$WB_MARK}" "${1:+ $1}"; }
_mb_end()   { printf '# <<< %s%s <<<' "${2:-$WB_MARK}" "${1:+ $1}"; }

marker_block_present() { # <file> [name] [mark]
  [ -f "$1" ] && grep -Fxq "$(_mb_start "${2:-}" "${3:-}")" "$1"
}

# marker_block_body <file> [name] [mark]: print the body of a block (no markers).
marker_block_body() {
  local s e
  s=$(_mb_start "${2:-}" "${3:-}"); e=$(_mb_end "${2:-}" "${3:-}")
  awk -v s="$s" -v e="$e" '$0==s{f=1;next} $0==e{f=0} f' "$1"
}

# marker_block_remove <file> <name> [mark]: delete a block (markers included).
marker_block_remove() {
  local file=$1 name=${2:-} s e tmp
  s=$(_mb_start "$name" "${3:-}"); e=$(_mb_end "$name" "${3:-}")
  tmp=$(mktemp)
  awk -v s="$s" -v e="$e" '$0==s{f=1;next} $0==e{f=0;next} !f' "$file" > "$tmp"
  cat "$tmp" > "$file"   # keep mode/ownership
  rm -f "$tmp"
}

marker_block_set() {
  local file=$1 name=${2:-} pos=${3:-bottom} body cur tmp
  body=$(cat)
  if [ -f "$file" ] && marker_block_present "$file" "$name"; then
    cur=$(marker_block_body "$file" "$name")
    if [ "$cur" = "$body" ]; then ok "marker block '${name:-main}' current in $file"; return 0; fi
    if is_dry_run; then dry_note "update marker block '${name:-main}' in $file"; return 0; fi
    backup_copy "$file"
    marker_block_remove "$file" "$name"
  elif is_dry_run; then
    dry_note "add marker block '${name:-main}' to $file"; return 0
  fi
  [ -f "$file" ] || : > "$file"
  tmp=$(mktemp)
  if [ "$pos" = "--top" ]; then
    { _mb_start "$name"; echo; printf '%s\n' "$body"; _mb_end "$name"; echo; echo; cat "$file"; } > "$tmp"
  else
    { cat "$file"; echo; _mb_start "$name"; echo; printf '%s\n' "$body"; _mb_end "$name"; echo; } > "$tmp"
  fi
  cat "$tmp" > "$file"; rm -f "$tmp"
  changed "wrote marker block '${name:-main}' in $file"
}

# backup_copy <file>: copy (not move) a file into the backup dir before editing it in place.
backup_copy() {
  local f=$1 rel
  [ -f "$f" ] || return 0
  rel=$(printf '%s' "$f" | sed 's#^/##; s#/#_#g')
  mkdir -p "$WB_BACKUP_DIR"
  cp -p "$f" "$WB_BACKUP_DIR/$rel"
}

# Blocks written by earlier generations of this toolkit, as "<mark>|<name>" (empty name =
# the main block). The single current block per file replaces them all.
_legacy_blocks() {
  printf '%s\n' 'ops-workbench|' 'ops-workbench|ssh'
  local n
  for n in dotfiles kubectl nvm go vm-expose "minimal aliases" "advanced aliases" "remote lab aliases"; do
    printf 'ops-workbench|%s\n' "$n"
  done
}

legacy_blocks_in() { # <file>: print each legacy "<mark>|<name>" found
  local f=$1 entry
  [ -f "$f" ] || return 0
  while IFS= read -r entry; do
    marker_block_present "$f" "${entry#*|}" "${entry%%|*}" && printf '%s\n' "$entry"
  done <<< "$(_legacy_blocks)"
  return 0
}

_legacy_label() { local m=${1%%|*} n=${1#*|}; printf '%s%s' "$m" "${n:+ $n}"; }

legacy_blocks_migrate() { # <file>
  local f=$1 entry found labels=""
  found=$(legacy_blocks_in "$f")
  [ -n "$found" ] || return 0
  if is_dry_run; then
    while IFS= read -r entry; do dry_note "remove legacy marker block '$(_legacy_label "$entry")' from $f"; done <<< "$found"
    return 0
  fi
  backup_copy "$f"
  while IFS= read -r entry; do
    marker_block_remove "$f" "${entry#*|}" "${entry%%|*}"
    labels="$labels$(_legacy_label "$entry"),"
  done <<< "$found"
  changed "removed legacy marker block(s) from $f: ${labels%,}"
}

file_sha() { # <path>: checksum or "-"
  if [ -e "$1" ]; then shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1; else echo "-"; fi
}
