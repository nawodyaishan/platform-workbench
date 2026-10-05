#!/usr/bin/env bash
# Profile: Ubuntu LTS lab VM. Sourced by workbench.sh.
# shellcheck disable=SC2034
MODULES=(base shell git ssh tailscale containers k8s lang cka devstack)
PKGS_BASE=(git curl wget jq tree rsync tar unzip vim tmux bash-completion lsof ca-certificates gnupg)
PKGS_NET=(dnsutils iproute2 iputils-ping traceroute tcpdump netcat-openbsd mtr-tiny ethtool)
PKGS_ADMIN=()
CONTAINER_ENGINE=docker
K8S_MINOR=1.35
GO_VERSION=1.25.1
# devstack extra (task devstack): full-stack toolchain. Go and Node versions are resolved
# at run time (latest stable, latest LTS); nvm is pinned to a release tag.
NVM_VERSION=v0.40.8
JAVA_MAJOR=25
PKGS_DEV=(build-essential pkg-config libssl-dev zlib1g-dev libffi-dev python3-venv python3-pip pipx
  procps file zip xz-utils ripgrep fd-find fzf bat yq httpie direnv shellcheck sqlite3
  postgresql-client redis-tools)
