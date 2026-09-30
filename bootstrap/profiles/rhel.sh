#!/usr/bin/env bash
# Profile: RHEL family (RHEL/Alma/Rocky 9), lab VM. No EPEL. Sourced by workbench.sh.
# shellcheck disable=SC2034
MODULES=(base shell git ssh tailscale containers k8s lang cka)
PKGS_BASE=(git curl wget jq tree rsync tar unzip vim tmux bash-completion lsof)
PKGS_NET=(bind-utils iproute iputils traceroute tcpdump nmap-ncat mtr ethtool)
PKGS_ADMIN=(firewalld policycoreutils-python-utils setroubleshoot-server lvm2 nfs-utils chrony tuned man-pages)
CONTAINER_ENGINE=podman
K8S_MINOR=1.35
GO_VERSION=1.25.1
