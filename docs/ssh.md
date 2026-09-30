# SSH and Tailscale

Tailscale provides private reachability, OpenSSH handles authentication, and tmux keeps the session alive. You always connect by name (`ssh rhel-lab`, `ssh ubuntu-lab`, `ssh proxmox`) and never by address.

New to SSH, or want the reasoning behind these defaults? Work through the [SSH tutorial](ssh-tutorial/README.md), which teaches SSH from a first login to hardened automation using this repository's files as the examples.

## Layout on the Mac

```text
~/.ssh/config                     # starts with a managed block: Include ~/.ssh/config.d/*.conf
~/.ssh/config.d/10-hosts.local.conf   # untracked: User, IdentityFile, temporary HostName
~/.ssh/config.d/50-workbench.conf     # symlink to config/ssh/workbench.conf
~/.ssh/cm/                        # connection-multiplexing sockets, mode 700
```

OpenSSH uses the first value it finds for each option, so the local file (`10-`) overrides the committed defaults (`50-`), and both override anything later in `~/.ssh/config`.

## Committed defaults

[config/ssh/workbench.conf](../config/ssh/workbench.conf) gives every registered host:

- `HostName %h`, so the alias resolves through Tailscale MagicDNS
- keepalives (`ServerAliveInterval 30`)
- connection multiplexing (`ControlMaster auto`, `ControlPersist 10m`), so repeated `ssh`/`task` calls reuse one authenticated connection
- `StrictHostKeyChecking accept-new`: new hosts are learned once, and a changed key is an error to investigate

It also sets `ForwardAgent no` for everything. Never copy the Mac private key to a host. When a trusted host briefly needs your agent (for example a one-off `git clone` over SSH), use an explicit `ssh -A <alias>` and end that session afterwards. For lasting GitHub access, use `task gh-key`.

## Everyday commands

```bash
task hosts                 # registry, resolved user@hostname, reachability
ssh -G rhel-lab            # effective settings for one alias
task rhel                  # SSH + attach/create tmux "main" (same as: task ssh HOST=rhel-lab)
ssh -O exit rhel-lab       # close a multiplexed master connection
```

Remote sessions use the stock tmux `Ctrl-b` prefix, so a nested session needs `Ctrl-b Ctrl-b`. The status bar accent is mauve locally and green over SSH, so you can tell the layers apart.

## On the Linux hosts

The `ssh` module installs and enables `sshd` and checks `~/.ssh/authorized_keys` permissions. It leaves password authentication alone. Disable it yourself in `/etc/ssh/sshd_config.d/` only after key login is confirmed from a second session.
