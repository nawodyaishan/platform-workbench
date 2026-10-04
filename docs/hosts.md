# Hosts and profiles

Each machine gets exactly one profile. Persistent Linux hosts are registered in [bootstrap/hosts.conf](../bootstrap/hosts.conf) as `<ssh-alias> <profile>`, and the same alias appears on the `Host` line of [config/ssh/workbench.conf](../config/ssh/workbench.conf). `task repo` checks that the two agree.

| Machine | Alias | Profile | Modules |
|---|---|---|---|
| macOS workstation | local | `macos` | base (Brewfile), shell, git, ssh (client), tailscale, containers (OrbStack check), k8s, lang |
| RHCSA VM (RHEL family, Proxmox guest) | `rhel-rhcsa01` | `rhel` | base, shell, git, ssh, tailscale, containers (podman), k8s, lang, cka |
| Development VM (Ubuntu LTS, Proxmox guest) | `dev-01` | `ubuntu` | base, shell, git, ssh, tailscale, containers (Docker CE), k8s (+ helm, k9s), lang, cka |
| Proxmox VE host | `proxmox` | `proxmox` | base, shell, ssh, tailscale |
| KodeKloud / disposable nodes, homelab `k3s-01` and kubeadm exam nodes | none | none | paste-in [snippet](kodekloud.md) only; reached by MagicDNS name |

## macOS workstation

This is the control machine. Ghostty runs tmux `main`, and you work locally or SSH to a named host. The checkout lives here. GUI apps (Ghostty, Tailscale, OrbStack) are checked for presence but not installed. Personal SSH identity and host addresses stay outside Git.

## RHEL lab (`rhel-rhcsa01`)

RHCSA practice: Linux administration, systemd, SELinux, networking, podman, and Kubernetes node diagnostics. Needs working BaseOS/AppStream repositories; EPEL is not used. `task rhel` opens its tmux `main`.

## Development VM (`dev-01`)

Daily development: builds, tests, agent CLIs, Kubernetes clients, containers and platform tooling. Docker CE, Kubernetes, Helm and Tailscale come from their vendor apt repositories. The Helm key is fingerprint-checked and k9s is checksum-checked. `task ubuntu` opens its tmux `main`.

## Proxmox

Minimal on purpose: SSH, Tailscale, the shared shell/tmux/Vim config, and a few host utilities. There are no developer stacks, no Kubernetes tools, no Git module, and no `pve-*` upgrades. It runs as root because stock Proxmox has no sudo. Any bootstrap or update needs a typed `proxmox` confirmation. Platform workloads on Proxmox belong in the separate homelab infrastructure repo (see [Boundary with homelab](#boundary-with-homelab)).

## Boundary with homelab

The Proxmox guests above are created, sized, started and stopped by the separate homelab repository, which also owns the host network, the operating-mode guard (`lab-mode.sh`), the k3s and kubeadm clusters, guest-agent integration, backups and recovery. This repository takes over once a guest boots with its name, a user account and Tailscale, and owns everything inside a user shell from then on.

- Never add VM lifecycle, memory sizing, cluster provisioning or Proxmox host configuration here.
- Every guest joins the tailnet and is reached by its MagicDNS name. Disposable guests (`k3s-01`, exam nodes) are not registered, so rebuilding them never touches this repo.
- Guests run only in the homelab's current operating mode, so `task hosts` reporting a guest as unreachable may simply mean it is stopped.

## Extras

Linux profiles accept `--extras` (comma-separated): `go` installs a checksum-verified Go tarball, `node` installs distro nodejs/npm, and `cka` installs NFS and etcd clients. Nothing extra is installed by default.

## Adding a host

1. Add `<alias> <profile>` to `bootstrap/hosts.conf`.
2. Add the alias to the `Host` line in `config/ssh/workbench.conf`.
3. Run `task check`, then follow [new-machine.md](new-machine.md).
