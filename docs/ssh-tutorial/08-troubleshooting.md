# 8. Troubleshooting

**Level:** reference · [Back to contents](README.md)

When SSH fails, work from the outside in: **name → network → server → authentication → session**. The tools below tell you which layer broke.

## The diagnosis routine

```bash
# 1. What will SSH actually do? (no connection)
mac$ ssh -G ubuntu-lab | grep -E '^(hostname|user|port|identityfile|proxyjump|controlpath) '

# 2. Does the name resolve, and is the host on the tailnet?
mac$ tailscale status | grep ubuntu-lab
mac$ task hosts                                  # registry, resolved user@hostname, reachability

# 3. Watch the conversation
mac$ ssh -v ubuntu-lab true                      # -vv / -vvv for more detail

# 4. Ask the server (from the console or a working session)
ubuntu-lab$ sudo journalctl -u ssh -n 50         # "-u sshd" on RHEL
ubuntu-lab$ sudo sshd -T | less                  # effective server config
```

In `ssh -v` output, look for:

- `Reading configuration data …`: which files were read, in order.
- `Connecting to … port 22` then `Connection established`: the network is fine.
- `Server host key: ssh-ed25519 SHA256:…`: the host key check.
- `Offering public key: …` then `Server accepts key` or `Authentications that can continue`: which keys were tried.
- `Authenticated to …`: authentication worked. Any problem after this is in the session.

## Common errors

| Symptom | Likely cause | Fix |
|---|---|---|
| `Could not resolve hostname ubuntu-lab` | Host not on the tailnet yet, or MagicDNS is off | `tailscale status`. Until the host joins, add a temporary `HostName` in `10-hosts.local.conf` ([chapter 3](03-client-config.md)) |
| `Connection timed out` | Host down, or a firewall is blocking it | Check the VM is running and `tailscale ping ubuntu-lab`. On RHEL, `sudo firewall-cmd --list-services` should include `ssh` |
| `Connection refused` | Reachable, but nothing listening on 22 | `systemctl status ssh` (or `sshd`) on the host. `task bootstrap HOST=…` enables it |
| `Permission denied (publickey)` | Key not in `authorized_keys`, wrong user, or bad permissions | `ssh -v` shows the user and keys offered. Check `User` in `ssh -G`. Run `task ssh:copy-id` again. Check modes ([chapter 2](02-keys.md)) and the server log |
| `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!` | Host reinstalled, or someone in the middle | **Stop and find out which.** If you reinstalled it, compare the new fingerprint on the console, then `ssh-keygen -R ubuntu-lab` |
| `Host key verification failed` in a script | New host with `BatchMode=yes` and no stored key | Connect once interactively. The repo's `accept-new` also handles this |
| `Too many authentication failures` | The agent offered many keys before the right one | Set `IdentityFile` plus `IdentitiesOnly yes` for that host |
| `UNPROTECTED PRIVATE KEY FILE!` | Private key readable by others | `chmod 600 ~/.ssh/id_ed25519` |
| New sessions hang, old ones are dead | Stale multiplexing master after a network change | `ssh -O exit ubuntu-lab` |
| Config change has no effect | The running master was opened with the old settings | `ssh -O exit ubuntu-lab`, then reconnect |
| Session freezes on a flaky network | Keepalives too slow, or none set | `ServerAliveInterval`/`CountMax` ([chapter 4](04-sessions.md)). Use tmux so nothing is lost |
| Garbled `vim`/`tmux`, `unknown terminal type` | Remote host lacks your terminal's terminfo | Ghostty's `ssh-terminfo` handles it. Otherwise `TERM=xterm-256color ssh …` |
| `open terminal failed: not a terminal` | Full-screen program run without a TTY | Add `-t` |
| `bind [127.0.0.1]:8080: Address already in use` | An old tunnel or master still holds the port | `ssh -O exit <host>`, or `lsof -i :8080` |
| `task verify` reports `unsafe SSH setting present` | `ForwardAgent yes` or `StrictHostKeyChecking no` in your config | Remove it and use `ssh -A` for one session instead ([chapter 6](06-security.md)) |

## Cheat sheet

```bash
# Connect and run
ssh ubuntu-lab                               # shell via alias
ssh ubuntu-lab 'uptime'                      # one command; exit code is returned
ssh -t ubuntu-lab htop                       # full-screen program needs a TTY
task ubuntu                                  # SSH + attach/create tmux "main"

# Keys
ssh-keygen -t ed25519 -C "alice@example.com" # new key (set a passphrase)
ssh-keygen -lf ~/.ssh/id_ed25519.pub         # fingerprint
ssh-copy-id -i ~/.ssh/id_ed25519.pub ubuntu-lab   # or: task ssh:copy-id HOST=ubuntu-lab
ssh-add -l                                   # keys in the agent
ssh-keygen -R ubuntu-lab                     # forget a host's stored key

# Config
ssh -G ubuntu-lab                            # effective client config, no connection
ssh -G -F config/ssh/workbench.conf rhel-lab # evaluate one file in isolation
sudo sshd -t && sudo sshd -T                 # server: syntax check, effective config

# Multiplexing
ssh -O check ubuntu-lab                      # master running?
ssh -O exit ubuntu-lab                       # close master (fixes most "stuck" issues)

# Transfer
scp file ubuntu-lab:/tmp/
rsync -av dir/ ubuntu-lab:dir/
tar -czf - dir | ssh ubuntu-lab 'tar -xzf - -C /tmp'

# Tunnels
ssh -N -L 8080:localhost:80 ubuntu-lab       # remote port 80 -> local 8080
ssh -N -R 9000:localhost:3000 ubuntu-lab     # local 3000 -> remote 9000
ssh -N -D 1080 ubuntu-lab                    # SOCKS proxy
ssh -J proxmox alice@192.0.2.40              # jump through a host

# Debug
ssh -v ubuntu-lab true
ssh -o BatchMode=yes -o ConnectTimeout=5 ubuntu-lab true && echo up
```

## Where to go next

- `man ssh_config` and `man sshd_config` are the authoritative option references. Search them for any option you meet here.
- [docs/ssh.md](../ssh.md) summarises how this repo's SSH setup fits together.
- [docs/new-machine.md](../new-machine.md) uses everything from chapters 1–3 to bring up a new host.

[Back to contents](README.md)
