# Learn SSH with platform-workbench

A hands-on SSH course that goes from a first login to scripted, hardened, multi-host automation. Instead of toy examples, every concept is tied to a real file in this repository, so you learn each feature *and* see how a working toolkit uses it.

## Who it is for

- **Beginners** who have typed `ssh` a few times and want to understand what is actually happening.
- **Intermediate users** who want a clean `~/.ssh/config`, faster connections and sessions that survive a dropped network.
- **Advanced users** who script over SSH, manage several hosts and want sensible security defaults.

You can start at any level. Each chapter lists what it assumes.

## What you need

- A Mac or Linux machine with the OpenSSH client (`ssh -V` prints a version).
- A clone of this repository. Most exercises are **read-only** and use `ssh -G -F config/ssh/workbench.conf …`, which reads a config file without connecting anywhere or touching your own `~/.ssh`.
- For the hands-on parts, **one Linux VM you control**. The examples call it `ubuntu-lab`, with user `alice` at `192.0.2.20`. Substitute your own values. No VM yet? On a Mac, turn on *System Settings → General → Sharing → Remote Login* and practise with `ssh localhost`.

Prompts show where a command runs:

```text
mac$          your workstation (the SSH client)
ubuntu-lab$   the remote Linux host (the SSH server)
```

## Learning path

| Level | Chapter | You will learn |
|---|---|---|
| Beginner | [1. Your first connection](01-first-connection.md) | Client and server, `ssh user@host`, host keys and `known_hosts`, one-off remote commands, `-t` |
| Beginner | [2. Keys instead of passwords](02-keys.md) | `ssh-keygen`, `authorized_keys`, `ssh-copy-id`, file permissions, `ssh-agent` |
| Intermediate | [3. The client config file](03-client-config.md) | `Host` blocks, first-value-wins, `Include`, layered config, tokens, `ssh -G` |
| Intermediate | [4. Fast, durable sessions](04-sessions.md) | Keepalives, connection multiplexing, tmux over SSH, `SSH_CONNECTION`, terminals and clipboard |
| Advanced | [5. Scripting over SSH](05-scripting.md) | Quoting, streaming data over stdin, remote heredocs, safe argument handling, testing without a host |
| Advanced | [6. Security and hardening](06-security.md) | Agent forwarding, per-host keys, host key policy, hardening `sshd`, keeping secrets out of Git |
| Advanced | [7. Tunnels and jump hosts](07-tunnels-and-jumps.md) | `-L`, `-R`, `-D` forwarding, `ProxyJump`, putting them in config |
| Reference | [8. Troubleshooting](08-troubleshooting.md) | A diagnosis routine, common errors and fixes, a command cheat sheet |

## The SSH files in this repository

| File | What it shows | Chapters |
|---|---|---|
| [config/ssh/workbench.conf](../../config/ssh/workbench.conf) | Shared client defaults: aliases, keepalives, multiplexing, host key policy, no agent forwarding | 1, 3, 4, 6 |
| [config/ssh/hosts.local.conf.example](../../config/ssh/hosts.local.conf.example) | Private per-machine overrides (`User`, first-contact `HostName`) kept out of Git | 3 |
| [bootstrap/modules/ssh.sh](../../bootstrap/modules/ssh.sh) | Installing `sshd`, wiring `~/.ssh/config`, permission and safety checks | 1, 2, 3, 6 |
| [scripts/remote.sh](../../scripts/remote.sh) | Real SSH automation: reachability checks, `ssh-copy-id`, streaming files, remote heredocs, per-host GitHub keys | 1, 2, 5, 6 |
| [bootstrap/hosts.conf](../../bootstrap/hosts.conf), [bootstrap/lib/hosts.sh](../../bootstrap/lib/hosts.sh) | The host registry that the SSH aliases must match | 3, 5 |
| [Taskfile.yml](../../Taskfile.yml) | `task ssh`, `task hosts`, `task ssh:copy-id`, `task gh-key`, and an `ssh -G` lint | 4, 5 |
| [config/tmux/tmux.conf](../../config/tmux/tmux.conf) | Detecting an SSH session, clipboard over SSH | 4 |
| [config/ghostty/config.ghostty](../../config/ghostty/config.ghostty) | Terminal integration for remote hosts (`ssh-terminfo`, `ssh-env`) | 4 |
| [scripts/test-remote.sh](../../scripts/test-remote.sh) | Testing SSH automation with a stub `ssh` and no real host | 5 |
| [scripts/check-secrets.sh](../../scripts/check-secrets.sh), [.gitignore](../../.gitignore) | Keeping private keys, addresses and local SSH files out of Git | 2, 6 |
| [bootstrap/modules/tailscale.sh](../../bootstrap/modules/tailscale.sh) | The network layer that makes hosts reachable by name | 1, 8 |

For a short reference of how the finished setup fits together, see [docs/ssh.md](../ssh.md).

## Ground rules used throughout

1. **Connect by name, never by address.** Addresses belong in private config, not in commands or scripts.
2. **Private keys never leave the machine they were created on.** Only `.pub` files travel.
3. **Look before you change.** `ssh -G` shows the effective config, and `--dry-run` shows a plan.
4. **Keep a second session open** whenever you change how a server accepts logins.
