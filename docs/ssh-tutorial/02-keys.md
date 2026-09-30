# 2. Keys instead of passwords

**Level:** beginner · **Assumes:** [chapter 1](01-first-connection.md) · [Back to contents](README.md)

Passwords can be guessed, phished and reused. SSH keys can't be guessed, are never sent to the server, and can be revoked one at a time. This chapter sets up key login the way this repo does.

## How key authentication works

A key is a **pair**:

| File | Where it lives | Who may see it |
|---|---|---|
| `~/.ssh/id_ed25519` | Only on your workstation | Nobody. Never copy, email or commit it |
| `~/.ssh/id_ed25519.pub` | Copied to every server you log in to | Anyone. It is public by design |

The server keeps a list of allowed public keys in `~/.ssh/authorized_keys`. When you connect, it sends a challenge that only the matching private key can sign. The private key never crosses the network.

## Create a key

```bash
mac$ ssh-keygen -t ed25519 -C "alice@example.com"
```

- `-t ed25519` is the modern default: short, fast and strong. Use RSA (`-t rsa -b 4096`) only for old systems that need it.
- `-C` is a comment that helps you recognise the key later. It doesn't affect security.
- **Set a passphrase.** It encrypts the private key on disk, so a stolen laptop backup is not a stolen login. The agent (below) means you type it rarely.

Show a key's fingerprint, which is how GitHub and `known_hosts` identify it:

```bash
mac$ ssh-keygen -lf ~/.ssh/id_ed25519.pub
```

## Permissions matter

SSH is strict about permissions on both ends. The client refuses a private key that other users can read (`UNPROTECTED PRIVATE KEY FILE`). The server ignores `authorized_keys` if it, `~/.ssh` or your home directory is writable by anyone else (the `StrictModes` setting). The safe modes are:

| Path | Mode |
|---|---|
| `~/.ssh/` | `700` |
| `~/.ssh/id_ed25519` (private) | `600` |
| `~/.ssh/authorized_keys` | `600` |
| `~/.ssh/config` | `600` (or `644`) |

This repo enforces them. On the Mac, [bootstrap/modules/ssh.sh](../../bootstrap/modules/ssh.sh) runs:

```bash
chmod 700 "$dir" "$dir/config.d" "$dir/cm"
```

On Linux, `verify` checks the server side:

```bash
if [ "$(stat -c %a "$HOME/.ssh/authorized_keys")" = 600 ]; then ok "authorized_keys mode 600"
```

> [!TIP]
> Notice `stat -c %a` on Linux but `stat -f %Lp` in the Mac branch of the same module. BSD and GNU tools differ, and portable scripts have to branch on the OS.

## Put your public key on the server

The standard tool is `ssh-copy-id`. It logs in once with your password, appends your public key to `~/.ssh/authorized_keys`, and fixes the permissions:

```bash
mac$ ssh-copy-id alice@192.0.2.20
mac$ ssh-copy-id -i ~/.ssh/id_ed25519.pub alice@192.0.2.20    # choose a specific key
```

This repo wraps it as `task ssh:copy-id HOST=ubuntu-lab [KEY=…]`. Look at the guard in [scripts/remote.sh](../../scripts/remote.sh):

```bash
case "$1" in *.pub) ;; *) die 'pass the PUBLIC key file (*.pub); private keys never leave the Mac' ;; esac
exec ssh-copy-id -i "$1" "$host"
```

A simple filename check makes the dangerous mistake of sending a private key impossible through this command.

Without `ssh-copy-id`, the manual equivalent is:

```bash
mac$ ssh alice@192.0.2.20 'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys' < ~/.ssh/id_ed25519.pub
```

`umask 077` makes anything created in that command private (`700` directories, `600` files).

## Prove key login works

```bash
mac$ ssh -o PasswordAuthentication=no -o BatchMode=yes alice@192.0.2.20 true && echo "key login works"
```

Forbidding the password fallback for this one command proves the key alone is enough. Do this **before** you ever disable password login on the server ([chapter 6](06-security.md)). The repo's `ssh` module deliberately leaves password authentication alone for exactly this reason:

```bash
info "password auth is left untouched; add your public key to ~/.ssh/authorized_keys yourself"
```

## `ssh-agent`: type the passphrase once

The agent holds decrypted keys in memory and signs challenges for you:

```bash
mac$ ssh-add ~/.ssh/id_ed25519     # asks for the passphrase once
mac$ ssh-add -l                    # list loaded keys
mac$ ssh-add -D                    # remove all keys from the agent
```

On macOS you can also store the passphrase in the login Keychain:

```bash
mac$ ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```

To make that automatic, add the following to your **private** `~/.ssh/config.d/10-hosts.local.conf` rather than the shared file, because Linux OpenSSH doesn't know the `UseKeychain` option:

```sshconfig
Host *
    IgnoreUnknown UseKeychain
    UseKeychain yes
    AddKeysToAgent yes
```

## Private keys and Git

This repository is public, so it has several layers of protection against committing a key:

- [.gitignore](../../.gitignore) ignores `id_ed25519*`, `id_rsa*`, `id_ecdsa*`, `*.pem` and `*.key`, but keeps `*.pub` trackable.
- [scripts/check-secrets.sh](../../scripts/check-secrets.sh) (`task secrets` and the pre-commit hook) fails on private key file names and on the text header that every private key file starts with.
- Remote runs send only Git-tracked files, so an untracked key in the checkout is never transferred ([chapter 5](05-scripting.md)).

## Exercises

1. Create a key with a passphrase and load it into the agent. Confirm with `ssh-add -l`.
2. Install it on your lab host with `ssh-copy-id`, then run the "prove key login works" command.
3. On the host, look at `~/.ssh/authorized_keys`. You'll find exactly the contents of your `.pub` file.
4. Keep one session open on the host, then run `chmod g+w ~/.ssh/authorized_keys` there. A new `ssh -o BatchMode=yes alice@192.0.2.20 true` from the Mac now fails, and the server log (`journalctl -u ssh`, or `-u sshd` on RHEL) says why. Restore it with `chmod 600 ~/.ssh/authorized_keys` from the open session.

**Next:** [3. The client config file](03-client-config.md)
