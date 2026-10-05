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

Linux profiles accept `--extras` (comma-separated): `go` installs a checksum-verified Go tarball, `node` installs distro nodejs/npm, and `cka` installs NFS and etcd clients. On `ubuntu`, `devstack` installs the [full-stack dev toolchain](#full-stack-dev-toolchain-ubuntu); with it on, devstack owns Go and Node and the `go`/`node` extras report `n/a`. Nothing extra is installed by default.

`--only MOD,...` limits a run to the listed modules of the profile, in profile order. A name the profile doesn't have is a usage error.

## Full-stack dev toolchain (Ubuntu)

A separate, opt-in command for any `ubuntu`-profile host, such as `dev-01`. It is never part of a plain `task bootstrap`.

```bash
task devstack -- --dry-run     # show every planned change, make none
task devstack                  # install
task devstack:verify           # read-only, offline
task devstack:update           # newest Node LTS, Go, Rust, AWS CLI, kind; named apt packages
```

The Make equivalents are `make devstack`, `make devstack-update` and `make devstack-verify` (`ARGS=--dry-run`). Each command runs the ubuntu profile with `--extras devstack --only base,shell,containers,k8s,devstack`, so Git, SSH, Tailscale and the CKA tools are not touched.

| Area | Tool | Source and check |
|---|---|---|
| Node | nvm (pinned tag) + the latest LTS Node as `default` | nvm `install.sh` with `PROFILE=/dev/null` (no rc edits) |
| JS package managers | yarn, pnpm | the `corepack` npm package's shims (Node 25+ no longer bundles Corepack); default versions cached once |
| Go | latest stable | `go.dev` tarball, SHA-256 checked, `/usr/local/go` |
| Rust | rustup + stable (`rustfmt`, `clippy`) | `sh.rustup.rs` with `--no-modify-path` |
| Java | Eclipse Temurin JDK (`JAVA_MAJOR`, 25) + Maven | Adoptium apt repo, key fingerprint pinned |
| Terraform, GitHub CLI | `terraform`, `gh` | HashiCorp and GitHub CLI apt repos, key fingerprints pinned |
| AWS | AWS CLI v2 | official per-user installer into `~/.local` (verifies its own download) |
| Kubernetes | `kind` (CLI only, no cluster is created) plus the `k8s` module's kubectl, crictl, Helm and k9s | GitHub release, SHA-256 checked |
| Containers | Docker CE, buildx, compose | the `containers` module |
| Homebrew | Homebrew on Linux, `/home/linuxbrew/.linuxbrew` | official `install.sh`, `NONINTERACTIVE=1`; `update` runs `brew update` only |
| CLIs and build deps | `PKGS_DEV` in `bootstrap/profiles/ubuntu.sh`: build-essential, ripgrep, fd (`fdfind`), fzf, bat (`batcat`), yq, httpie, direnv, shellcheck, sqlite3, postgresql-client, redis-tools, pipx and more | Ubuntu apt |

Notes:

- **Trust.** The nvm, rustup, Homebrew and AWS installers are vendor scripts fetched over HTTPS at run time, downloaded completely before they run, and never run as root. nvm is pinned to a tag; the others have no stable tag. Installer output goes to `$TMPDIR/platform-workbench-devstack.log`.
- **Key rotation.** A pinned apt key that no longer matches fails closed with `FAIL`. Re-check the vendor's published fingerprint before updating the pin in `devstack.sh`. HashiCorp last rotated on 2026-09-10.
- **Node LTS moves.** Node 26 becomes LTS on 2026-10-28. The next `task devstack:update` after that installs it, reinstalls global packages (corepack) from the old version and repoints `default`. Older versions stay installed.
- **Shell wiring.** `config/shell/bashrc` loads nvm and `brew shellenv` and puts `~/.cargo/bin`, `/usr/local/go/bin` and `~/.local/bin` on `PATH`. Open a new shell after the first run.
- **arm64.** Everything has arm64 builds. Homebrew on Linux arm64 is a lower support tier, so a failed install there is `WARN`, not `FAIL`.
- **From the Mac.** `task bootstrap HOST=dev-01 -- --extras devstack --only base,shell,containers,k8s,devstack` runs the same thing remotely (the payload is the tracked files only, so commit first). Remote `verify` takes no flags, so check the stack on the host with `task devstack:verify`.
- **Out of scope.** Credentials (`aws configure`, `gh auth login`, `docker login`), editors, databases as services, and creating Kubernetes clusters (that belongs to the homelab repo).

## Adding a host

1. Add `<alias> <profile>` to `bootstrap/hosts.conf`.
2. Add the alias to the `Host` line in `config/ssh/workbench.conf`.
3. Run `task check`, then follow [new-machine.md](new-machine.md).
