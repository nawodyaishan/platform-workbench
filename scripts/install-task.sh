#!/usr/bin/env bash
# Install Task (go-task) on a Linux host: Ubuntu/Debian, RHEL-family or Proxmox VE.
#
#   install-task.sh [--distro ubuntu|rhel|proxmox|auto] [--method auto|repo|binary]
#                   [--bin-dir DIR] [--force] [--dry-run]
#
# Works as root (stock Proxmox has no sudo) or as a normal user. sudo is used only when
# not root and only for the package-manager route; without it the binary goes to ~/.local/bin.
# auto method: Proxmox -> binary (its enterprise apt repo fails `apt-get update` without a
# subscription); other distros -> Cloudsmith package repo, falling back to the binary.
# The binary route uses the official install script, which verifies the release checksum.
set -euo pipefail

DISTRO=auto; METHOD=auto; BIN_DIR=""; FORCE=0; DRY_RUN=0
usage() { sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit "${1:-2}"; }
while [ $# -gt 0 ]; do
  case "$1" in
    --distro)  [ $# -ge 2 ] || usage; DISTRO=$2; shift 2 ;;
    --method)  [ $# -ge 2 ] || usage; METHOD=$2; shift 2 ;;
    --bin-dir) [ $# -ge 2 ] || usage; BIN_DIR=$2; shift 2 ;;
    --force)   FORCE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage 0 ;;
    *) echo "unknown option: $1" >&2; usage ;;
  esac
done
case "$METHOD" in auto|repo|binary) ;; *) echo "bad --method: $METHOD" >&2; usage ;; esac

say() { printf '%s\n' "$*"; }
run() {
  if [ "$DRY_RUN" = 1 ]; then say "would run: $*"; else "$@"; fi
}

[ "${INSTALL_TASK_ASSUME_LINUX:-0}" = 1 ] || [ "$(uname -s)" = Linux ] || { echo "install-task.sh targets Linux; on macOS use: brew install go-task" >&2; exit 2; }

if [ "$FORCE" = 0 ] && command -v task >/dev/null 2>&1; then
  say "task already installed: $(command -v task) ($(task --version 2>/dev/null | head -1))"
  exit 0
fi

# Detect the family from os-release; Proxmox is Debian underneath, marked by /etc/pve.
id=""; like=""
if [ -r /etc/os-release ]; then
  id=$(. /etc/os-release && printf '%s' "${ID:-}")
  like=$(. /etc/os-release && printf '%s' "${ID_LIKE:-}")
fi
if [ "$DISTRO" = auto ]; then
  if [ -d /etc/pve ] || command -v pveversion >/dev/null 2>&1; then DISTRO=proxmox
  else
    case " $id $like " in
      *" ubuntu "*|*" debian "*) DISTRO=ubuntu ;;
      *" rhel "*|*" fedora "*|*" centos "*) DISTRO=rhel ;;
      *) DISTRO=other ;;
    esac
  fi
fi
case "$DISTRO" in ubuntu|rhel|proxmox|other) ;; *) echo "bad --distro: $DISTRO" >&2; usage ;; esac

if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi
have_sudo=1
[ -z "$SUDO" ] || command -v sudo >/dev/null 2>&1 || have_sudo=0

command -v curl >/dev/null 2>&1 || {
  echo "curl is required. Install it first: apt-get install -y curl ca-certificates  (Debian family)  |  dnf install -y curl  (RHEL family)" >&2
  exit 1
}

install_repo() {
  local setup pm
  case "$DISTRO" in
    ubuntu) setup=setup.deb.sh; pm="apt-get install -y task" ;;
    rhel)   setup=setup.rpm.sh; pm="dnf install -y task" ;;
    *) return 1 ;;
  esac
  [ "$have_sudo" = 1 ] || return 1
  say "installing Task from the Cloudsmith $DISTRO repository"
  if [ "$DRY_RUN" = 1 ]; then
    say "would run: curl -1sLf https://dl.cloudsmith.io/public/task/task/$setup | ${SUDO:+$SUDO -E }bash"
    say "would run: ${SUDO:+$SUDO }$pm"
    return 0
  fi
  curl -1sLf "https://dl.cloudsmith.io/public/task/task/$setup" | ${SUDO:+$SUDO -E} bash || return 1
  # shellcheck disable=SC2086
  ${SUDO:+$SUDO} $pm
}

install_binary() {
  local dir=$BIN_DIR
  if [ -z "$dir" ]; then
    if [ "$(id -u)" -eq 0 ]; then dir=/usr/local/bin; else dir="$HOME/.local/bin"; fi
  fi
  say "installing the Task release binary into $dir"
  run mkdir -p "$dir"
  if [ "$DRY_RUN" = 1 ]; then
    say "would run: sh -c \"\$(curl -fsSL https://taskfile.dev/install.sh)\" -- -d -b $dir"
    return 0
  fi
  sh -c "$(curl -fsSL https://taskfile.dev/install.sh)" -- -d -b "$dir"
  case ":$PATH:" in *":$dir:"*) ;; *) say "note: add $dir to PATH to run 'task' from anywhere" ;; esac
}

say "distro: $DISTRO  method: $METHOD"
case "$METHOD" in
  repo)   install_repo || { echo "package-repo install failed or needs sudo; retry with --method binary" >&2; exit 1; } ;;
  binary) install_binary ;;
  auto)
    if [ "$DISTRO" = proxmox ] || [ "$DISTRO" = other ]; then install_binary
    else install_repo || { say "package route unavailable; falling back to the binary"; install_binary; }
    fi ;;
esac

if [ "$DRY_RUN" = 0 ]; then
  hash -r
  if command -v task >/dev/null 2>&1; then say "ok: $(task --version | head -1)"
  else say "installed, but 'task' is not on PATH yet (open a new shell or add the bin dir)"; fi
fi
