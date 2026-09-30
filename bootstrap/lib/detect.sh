#!/usr/bin/env bash
# OS detection and profile/OS sanity checks. Sourced only.
# shellcheck disable=SC2034,SC2015

# detect_os: sets WB_OS (macos|linux), OS_ID, OS_ID_LIKE, OS_VERSION_ID, OS_PRETTY_NAME,
# OS_FAMILY (brew|dnf|apt), ARCH (amd64|arm64).
detect_os() {
  local m
  m=$(uname -m)
  case "$m" in
    x86_64|amd64) ARCH=amd64 ;;
    aarch64|arm64) ARCH=arm64 ;;
    *) ARCH=$m ;;
  esac
  OS_ID=""; OS_ID_LIKE=""; OS_VERSION_ID=""; OS_PRETTY_NAME=""
  if [ "$(uname -s)" = "Darwin" ]; then
    WB_OS=macos; OS_FAMILY=brew; OS_ID=macos
    OS_VERSION_ID=$(sw_vers -productVersion 2>/dev/null || echo "")
    OS_PRETTY_NAME="macOS $OS_VERSION_ID"
    return 0
  fi
  WB_OS=linux
  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_ID=${ID:-}; OS_ID_LIKE=${ID_LIKE:-}; OS_VERSION_ID=${VERSION_ID:-}; OS_PRETTY_NAME=${PRETTY_NAME:-}
  fi
  if have dnf; then OS_FAMILY=dnf
  elif have apt-get; then OS_FAMILY=apt
  else OS_FAMILY=unknown
  fi
}

os_is_rhel_family() {
  case " $OS_ID $OS_ID_LIKE " in
    *" rhel "*|*" centos "*|*" fedora "*|*" rocky "*|*" almalinux "*) return 0 ;;
  esac
  return 1
}

# profile_matches_host <profile>: 0 when this machine fits the profile.
profile_matches_host() {
  case "$1" in
    macos)   [ "$WB_OS" = macos ] ;;
    rhel)    [ "$WB_OS" = linux ] && [ "$OS_FAMILY" = dnf ] && os_is_rhel_family ;;
    ubuntu)  [ "$WB_OS" = linux ] && [ "$OS_FAMILY" = apt ] && [ "$OS_ID" = ubuntu ] ;;
    proxmox) [ "$WB_OS" = linux ] && have pveversion ;;
    *) return 1 ;;
  esac
}

# check_profile_host <profile> <force>: refuse to run a profile on the wrong machine.
check_profile_host() {
  local p=$1 force=${2:-0}
  if profile_matches_host "$p"; then return 0; fi
  if [ "$force" = "1" ]; then
    warn "profile '$p' does not match this host ($OS_PRETTY_NAME) - continuing due to --force-profile"
    return 0
  fi
  die "profile '$p' does not match this host ($OS_PRETTY_NAME, package manager: $OS_FAMILY); use --force-profile only for container tests"
}

# check_root_policy <profile>: Linux profiles run unprivileged, except proxmox.
check_root_policy() {
  local p=$1
  [ "$WB_OS" = linux ] || return 0
  if [ "$p" = proxmox ]; then
    [ "$(id -u)" -eq 0 ] || die "profile proxmox must run as root (there is no sudo on a stock Proxmox host)"
  elif [ "$(id -u)" -eq 0 ] && [ "${WB_FORCE_PROFILE:-0}" != "1" ]; then
    die "profile '$p' refuses to run as root; run as your normal user (sudo is used where needed)"
  fi
}
