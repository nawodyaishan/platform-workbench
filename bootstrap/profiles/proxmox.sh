#!/usr/bin/env bash
# Profile: Proxmox VE host. Minimal on purpose: SSH, Tailscale, shell config and host
# utilities only; no Git, dev stacks, or pve-* upgrades. Runs as root.
# shellcheck disable=SC2034
MODULES=(base shell ssh tailscale)
PKGS_BASE=(curl jq lsof htop tmux vim)
PKGS_NET=(dnsutils mtr-tiny tcpdump ethtool)
PKGS_ADMIN=()
CONTAINER_ENGINE=none
