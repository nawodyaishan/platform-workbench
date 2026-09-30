# Hosts and profiles

Each machine gets exactly one profile. Persistent Linux hosts are registered in [bootstrap/hosts.conf](../bootstrap/hosts.conf) as `<ssh-alias> <profile>`, and the same alias appears on the `Host` line of [config/ssh/workbench.conf](../config/ssh/workbench.conf). `task repo` checks that the two agree.

| Machine | Alias | Profile | Modules |
|---|---|---|---|
| macOS workstation | local | `macos` | base (Brewfile), shell, git, ssh (client), tailscale, containers (OrbStack check), k8s, lang |
| RHEL-family VM (UTM) | `rhel-lab` | `rhel` | base, shell, git, ssh, tailscale, containers (podman), k8s, lang, cka |
| Ubuntu LTS VM | `ubuntu-lab` | `ubuntu` | base, shell, git, ssh, tailscale, containers (Docker CE), k8s (+ helm, k9s), lang, cka |
| Proxmox VE host | `proxmox` | `proxmox` | base, shell, ssh, tailscale |
| KodeKloud / disposable nodes | none | none | paste-in [snippet](kodekloud.md) only |

## macOS workstation

This is the control machine. Ghostty runs tmux `main`, and you work locally or SSH to a named host. The checkout lives here. GUI apps (Ghostty, Tailscale, OrbStack) are checked for presence but not installed. Personal SSH identity and host addresses stay outside Git.

## RHEL lab

Linux administration, systemd, SELinux, networking, podman, and Kubernetes node diagnostics. Needs working BaseOS/AppStream repositories; EPEL is not used. `task rhel` opens its tmux `main`.

## Ubuntu lab

Kubernetes, containers and platform tooling. Docker CE, Kubernetes, Helm and Tailscale come from their vendor apt repositories. The Helm key is fingerprint-checked and k9s is checksum-checked. `task ubuntu` opens its tmux `main`.

## Proxmox

Minimal on purpose: SSH, Tailscale, the shared shell/tmux/Vim config, and a few host utilities. There are no developer stacks, no Kubernetes tools, no Git module, and no `pve-*` upgrades. It runs as root because stock Proxmox has no sudo. Any bootstrap or update needs a typed `proxmox` confirmation. Platform workloads on Proxmox belong in a separate infrastructure project.

## Extras

Linux profiles accept `--extras` (comma-separated): `go` installs a checksum-verified Go tarball, `node` installs distro nodejs/npm, and `cka` installs NFS and etcd clients. Nothing extra is installed by default.

## Adding a host

1. Add `<alias> <profile>` to `bootstrap/hosts.conf`.
2. Add the alias to the `Host` line in `config/ssh/workbench.conf`.
3. Run `task check`, then follow [new-machine.md](new-machine.md).
