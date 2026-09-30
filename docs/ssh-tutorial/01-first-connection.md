# 1. Your first connection

**Level:** beginner · **Assumes:** a terminal · [Back to contents](README.md)

By the end of this chapter you will know what happens when you type `ssh`, how SSH decides it is talking to the right machine, and how to run a single command remotely.

## What SSH is

SSH (Secure Shell) gives you an encrypted, authenticated channel to another machine. There are two programs:

| Side | Program | Job |
|---|---|---|
| Client | `ssh` | Runs on your workstation and starts the connection |
| Server | `sshd` | Runs on the remote host, listens on TCP port 22 and checks who you are |

A connection happens in three steps:

1. **The server proves who it is** with its *host key*.
2. **You prove who you are** with a password or, better, a key (chapter 2).
3. **A session opens:** a shell, a single command, a file transfer or a tunnel.

## Make sure the server is running

On most Linux servers `sshd` is installed and running already. This repo's `ssh` module makes sure. Here is the relevant part of [bootstrap/modules/ssh.sh](../../bootstrap/modules/ssh.sh):

```bash
_sshd_unit() { if systemctl list-unit-files 2>/dev/null | grep -q '^sshd\.service'; then echo sshd; else echo ssh; fi; }
```

The service has a different name on different distributions, `sshd` on RHEL and `ssh` on Ubuntu, so the module detects it rather than guessing. Check yours:

```bash
ubuntu-lab$ systemctl status ssh      # Ubuntu / Debian / Proxmox
rhel-lab$   systemctl status sshd     # RHEL / Alma / Rocky
```

## Connect

```bash
mac$ ssh alice@192.0.2.20
```

- `alice` is the account **on the remote host**. If you leave it out, `ssh` uses your local username.
- `192.0.2.20` is the host's address. A DNS name works too.
- Use `-p 2222` if the server listens on a different port.

Leave with `exit` or `Ctrl-D`.

> [!NOTE]
> This repository never puts real addresses in commands or files. You will replace `alice@192.0.2.20` with a short name such as `ubuntu-lab` in [chapter 3](03-client-config.md).

## Host keys and `known_hosts`

The first time you connect, you see something like this:

```text
The authenticity of host '192.0.2.20 (192.0.2.20)' can't be established.
ED25519 key fingerprint is SHA256:Xk3…9Qw.
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```

Every server has a **host key pair**. The client has never seen this one, so it asks you to confirm it. After you type `yes`, the key is saved to `~/.ssh/known_hosts`, and every later connection must present the same key. This model is called *trust on first use*.

To really verify the fingerprint, read it on the server through a channel you already trust, such as the VM console, and compare it with the prompt:

```bash
ubuntu-lab$ ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

### How this repo handles it

[config/ssh/workbench.conf](../../config/ssh/workbench.conf) sets:

```sshconfig
StrictHostKeyChecking accept-new
```

| Value | New host | Changed key |
|---|---|---|
| `ask` (default) | Prompts you | Refuses |
| `accept-new` (this repo) | Saves the key silently | **Refuses** |
| `yes` | Refuses (key must already be known) | Refuses |
| `no` | Saves silently | Connects anyway: **never use this** |

`accept-new` removes the prompt for brand-new lab hosts but still stops you when a known host's key changes. That is exactly the case that signals either a reinstall or an attack. [Chapter 6](06-security.md) covers why `no` is dangerous, and [chapter 8](08-troubleshooting.md) covers what to do when the key has changed.

## Run one command instead of a shell

Put a command after the host and SSH runs it, prints its output, and returns its **exit status**:

```bash
mac$ ssh alice@192.0.2.20 hostname
mac$ ssh alice@192.0.2.20 'uptime; df -h /'
mac$ ssh alice@192.0.2.20 true && echo reachable
```

This repo uses exactly that last pattern to check whether each host is up. From [scripts/remote.sh](../../scripts/remote.sh) (`task hosts`):

```bash
if ssh -o BatchMode=yes -o ConnectTimeout=5 "$h" true >/dev/null 2>&1; then state=ok; else state=unreachable; fi
```

- `true` does nothing and exits 0, so success means "I could log in".
- `BatchMode=yes` means never stop to ask for a password or passphrase. Fail instead. Essential in scripts.
- `ConnectTimeout=5` gives up after five seconds instead of hanging.

## Interactive programs need `-t`

When you pass a command, SSH does **not** allocate a terminal (a TTY) by default. That's fine for `hostname` but breaks full-screen programs such as `top`, `vim` or `tmux`. Force one with `-t`:

```bash
mac$ ssh alice@192.0.2.20 top          # "not a terminal" style errors
mac$ ssh -t alice@192.0.2.20 top       # works
```

The `task ssh` command in [Taskfile.yml](../../Taskfile.yml) uses `ssh -t` because it starts tmux on the remote side. [Chapter 4](04-sessions.md) takes it apart.

## Where the network comes from

SSH needs to *reach* the host before it can authenticate. This repo splits the two jobs:

- **Tailscale** provides private reachability and names (MagicDNS), so `ubuntu-lab` resolves from anywhere on your tailnet without opening port 22 to the internet. See [bootstrap/modules/tailscale.sh](../../bootstrap/modules/tailscale.sh).
- **OpenSSH** does authentication and the session itself.

Before a new host has joined the tailnet, you reach it by address. [docs/new-machine.md](../new-machine.md) shows that temporary step.

## Exercises

1. Connect to your lab host, run `exit`, then connect again. Notice that the second time there's no fingerprint prompt.
2. Look at the stored entry: `grep -c . ~/.ssh/known_hosts` shows how many host keys you trust.
3. Run `ssh alice@192.0.2.20 'exit 3'; echo $?`. The local `$?` is the remote exit code.
4. Compare `ssh alice@192.0.2.20 tty` with `ssh -t alice@192.0.2.20 tty`.

**Next:** [2. Keys instead of passwords](02-keys.md)
