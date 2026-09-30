#!/usr/bin/env bash
# cka: opt-in exam-practice extras (--extras cka): NFS client and etcd client.
# shellcheck disable=SC2034,SC2015

_cka_pkgs() {
  case "$OS_FAMILY" in
    dnf) echo "nfs-utils" ;;
    apt) echo "nfs-common etcd-client" ;;
  esac
}

cka_bootstrap() {
  hdr "cka extras"
  if ! extra_on cka; then na "cka extra not requested"; return 0; fi
  [ "$WB_OS" = linux ] || { na "cka extras are Linux-only"; return 0; }
  require_sudo
  # shellcheck disable=SC2046
  pm_install $(_cka_pkgs)
  [ "$OS_FAMILY" = dnf ] && warn "etcdctl is not packaged for RHEL; copy it from the etcd release if the exam practice needs it"
  return 0
}

cka_update() { cka_bootstrap; }

cka_verify() {
  hdr "cka extras (verify)"
  if ! extra_on cka; then na "cka extra not requested"; return 0; fi
  # shellcheck disable=SC2046
  pm_check $(_cka_pkgs)
}
