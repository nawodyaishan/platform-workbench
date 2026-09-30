# platform-workbench

A small, profile-driven toolkit for a platform-engineering workstation and its lab hosts. From one checkout on a Mac it installs, updates and verifies:

- **macOS workstation:** Ghostty, tmux, Vim, Git, OpenSSH, Tailscale, container and Kubernetes tooling
- **RHEL and Ubuntu lab VMs:** the same shell, tmux, Vim and Git setup, plus sshd, Tailscale, podman or Docker, kubectl/kubeadm and CKA practice tools
- **Proxmox host:** minimal: SSH, Tailscale, the shared shell config and a few host utilities
- **KodeKloud / disposable nodes:** a paste-in, session-only shell snippet

Every tool has one canonical config file (aliases, tmux, Vim, Git, SSH, Ghostty). Hosts are reached by name (`ssh rhel-lab`) over Tailscale, and a fresh host can be bootstrapped from the Mac before this repository is ever cloned on it.

## Quick start

Requirements on the Mac: [Homebrew](https://brew.sh) and [Task](https://taskfile.dev) (`brew install go-task`).

```bash
git clone https://github.com/nawodyaishan/platform-workbench.git
cd platform-workbench
task bootstrap -- --dry-run      # review the plan
task bootstrap                   # apply it (idempotent; backs up anything it replaces)
task verify                      # read-only health check
```

Then bring up a lab host by name. See [docs/new-machine.md](docs/new-machine.md) for first contact.

```bash
task ssh:copy-id HOST=ubuntu-lab
task bootstrap HOST=ubuntu-lab -- --dry-run
task bootstrap HOST=ubuntu-lab
task ubuntu                      # SSH + tmux "main"
```

## Commands

| Command | What it does |
|---|---|
| `task bootstrap` / `update` / `verify` | Lifecycle for this machine (`macos` on a Mac, otherwise `PROFILE=rhel\|ubuntu\|proxmox`) |
| `task bootstrap HOST=<alias>` (and `update`, `verify`) | The same lifecycle on a registered host, driven from the Mac |
| `task verify:all` | Verify the Mac and every registered host |
| `task main` | Attach to (or create) the local tmux session `main` |
| `task ssh HOST=<alias>`, `task rhel` / `ubuntu` / `proxmox` | SSH to a host and attach its tmux `main` |
| `task hosts` | Registered hosts, resolved SSH target, reachability |
| `task ssh:copy-id HOST=<alias> [KEY=…pub]` | Install a public key on a new host |
| `task gh-key HOST=<alias>` | Give a host its own GitHub key (asks before publishing) |
| `task kk` | Copy the KodeKloud shell snippet to the clipboard |
| `task check` | `lint` + `secrets` + `repo` |
| `task test:remote`, `task test:profiles` | Offline remote-flow tests; container smoke tests for the Linux profiles |
| `task hooks` | Install the pre-commit hook (secret scan, Markdown formatting) |

Lifecycle flags go after `--`: `--dry-run`, `--yes`, `--extras go,node,cka`.

## Layout

```text
bootstrap/
  workbench.sh        lifecycle engine: <bootstrap|update|verify> --profile <name>
  hosts.conf          registered hosts: <ssh-alias> <profile>
  lib/                detection, package managers, marker blocks, host registry
  modules/            base shell git ssh tailscale containers k8s lang cka
  profiles/           macos (+ Brewfile), rhel, ubuntu, proxmox
config/               canonical shell, tmux, vim, git, ssh and ghostty configs
kodekloud/            paste-in shell snippet for disposable lab nodes
scripts/              remote transport, secret scan, repo checks, tests, git hook
docs/                 hosts, new-machine, ssh, config, kodekloud, cheatsheets
```

## Documentation

- [docs/hosts.md](docs/hosts.md): profiles and what each machine gets
- [docs/new-machine.md](docs/new-machine.md): bootstrapping a Mac or a fresh Linux host
- [docs/ssh.md](docs/ssh.md): named-host OpenSSH and Tailscale
- [docs/config.md](docs/config.md): the canonical configs and how they are wired
- [docs/kodekloud.md](docs/kodekloud.md): disposable-lab shell snippet
- [docs/cheatsheets.md](docs/cheatsheets.md): Kubernetes, Linux and Terraform lab commands

## Safety model

- **Nothing private in Git.** Host addresses, SSH users, identity files and Tailscale auth live outside the repository (`~/.ssh/config.d/10-hosts.local.conf`, interactive `tailscale up`). `task secrets` and the pre-commit hook reject private keys, tokens, private IP ranges, tailnet names and personal emails.
- **Only tracked files leave the Mac.** Remote runs stream `git ls-files` output over SSH. No private key, agent or Git credential is forwarded, and `ForwardAgent no` is the default.
- **Idempotent and reversible.** Bootstrap owns only marked blocks and symlinks, and it backs up anything it replaces to `~/.platform-workbench-backup/`. `verify` never changes anything, and `--dry-run` shows every change first.
- **Scoped updates.** `update` upgrades only the packages a profile manages, never the whole system. Proxmox changes need a typed confirmation.

## License

[MIT](LICENSE)
