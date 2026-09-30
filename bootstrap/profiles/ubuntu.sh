#!/usr/bin/env bash
# Profile: Ubuntu LTS lab VM. Sourced by workbench.sh.
# shellcheck disable=SC2034
MODULES=(base shell git ssh tailscale containers k8s lang cka)
PKGS_BASE=(git curl wget jq tree rsync tar unzip vim tmux bash-completion lsof ca-certificates gnupg)
PKGS_NET=(dnsutils iproute2 iputils-ping traceroute tcpdump netcat-openbsd mtr-tiny ethtool)
PKGS_ADMIN=()
CONTAINER_ENGINE=docker
K8S_MINOR=1.35
GO_VERSION=1.25.1
