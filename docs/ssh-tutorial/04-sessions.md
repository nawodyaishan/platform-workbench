# 4. Fast, durable sessions

**Level:** intermediate · **Assumes:** [chapter 3](03-client-config.md) · [Back to contents](README.md)

A good SSH setup notices dead connections quickly, doesn't pay the login cost again and again, and keeps your work alive when the network drops. The repo gets all three from a handful of options plus tmux.

## Keepalives: notice a dead connection

When Wi-Fi drops or a laptop sleeps, a TCP connection can look open for a long time, and your terminal just freezes. Keepalives make the client probe the server through the encrypted channel:

```sshconfig
ServerAliveInterval 30   # after 30 s of silence, send a probe
ServerAliveCountMax 4    # give up after 4 unanswered probes
```

With the repo's lab-host values, a dead link is detected after about 30 × 4 = **2 minutes**, and `ssh` exits cleanly instead of hanging. Other hosts get `60 × 3` from `Host *`. Probes also keep NAT routers and firewalls from forgetting an idle connection.

> [!NOTE]
> `ServerAlive*` is the client probing the server. The server can probe clients too, with `ClientAliveInterval` in `sshd_config`. `TCPKeepAlive` works at the TCP layer and can be spoofed, so the `ServerAlive*` options are the ones to rely on.

## Multiplexing: log in once, reuse the connection

Every `ssh` normally does a full handshake and authentication. The repo's automation makes many calls in a row: one `task bootstrap HOST=…` runs about five `ssh` commands. **Connection multiplexing** lets later calls ride on the first one:

```sshconfig
ControlMaster auto          # become the master if none exists, otherwise reuse it
ControlPath ~/.ssh/cm/%C    # where the master's control socket lives
ControlPersist 10m          # keep the master in the background 10 min after the last session
```

- The first `ssh dev-01` authenticates and opens a socket in `~/.ssh/cm/`.
- Later `ssh`, `scp` or `rsync` calls to the same host within ten minutes reuse it and start almost instantly, with no new authentication.
- `%C` gives each user, host and port combination its own short socket name.

The socket directory must be private, since anyone who can use your socket can use your session. The `ssh` module creates it with mode `700`, and `verify` checks it:

```bash
[ -d "$dir/cm" ] && [ "$(stat -f %Lp "$dir/cm")" = 700 ] && ok "SSH control directory mode 700"
```

Control the master directly:

```bash
mac$ ssh -O check dev-01     # is a master running?
mac$ ssh -O exit dev-01      # close it now
```

Things to know:

- Options that affect the whole connection (user, port, forwarding set when the master opened) come from the **master**. After changing config, run `ssh -O exit <host>` so the next connection picks up the change.
- After a network change, a stale master can make new sessions hang. `ssh -O exit` fixes it.

Feel the difference:

```bash
mac$ ssh -O exit dev-01 2>/dev/null; time ssh dev-01 true   # full handshake
mac$ time ssh dev-01 true                                   # multiplexed
```

## tmux: sessions that survive disconnects

Even with keepalives, a dropped connection kills the remote shell and everything running in it. tmux runs on the **server**, so your programs keep running while you're gone and you reattach later. The repo's `task ssh` in [Taskfile.yml](../../Taskfile.yml) packs that into one command:

```bash
ssh -t "{{.HOST}}" 'command -v tmux >/dev/null && exec tmux new-session -A -s main || exec "${SHELL:-/bin/bash}" -l'
```

Read it piece by piece:

| Part | Meaning |
|---|---|
| `ssh -t` | Allocate a terminal. tmux is full-screen ([chapter 1](01-first-connection.md)) |
| `'…'` single quotes | The whole command is sent to the remote shell unexpanded, so `${SHELL}` is the **remote** user's shell ([chapter 5](05-scripting.md)) |
| `command -v tmux >/dev/null &&` | Only try tmux if it is installed |
| `exec tmux new-session -A -s main` | Attach to the session `main` if it exists (`-A`), otherwise create it |
| `\|\| exec "${SHELL:-/bin/bash}" -l` | Fallback: a normal login shell |
| `exec` | Replace the remote shell, so exiting tmux ends the SSH session cleanly |

`task rhel`, `task ubuntu` and `task proxmox` are shortcuts for `task ssh HOST=…`. Disconnect on purpose with `Ctrl-b d`, run `task ubuntu` again, and you're back where you were.

## How a program knows it is running over SSH

`sshd` sets environment variables in every session:

```bash
dev-01$ echo "$SSH_CONNECTION"   # client-ip client-port server-ip server-port
dev-01$ echo "$SSH_TTY"          # set only when a terminal was allocated
```

[config/tmux/tmux.conf](../../config/tmux/tmux.conf) uses `SSH_CONNECTION` to colour the status bar differently on remote hosts, so a tmux inside another tmux is easy to spot:

```tmux
if-shell '[ -n "$SSH_CONNECTION" ]' \
  'set -g @accent "#a6e3a1"' \
  'set -g @accent "#cba6f7"'
```

Mauve means local, green means you're on a remote host. When you nest sessions (local tmux, then SSH, then remote tmux), `Ctrl-b` goes to the outer one. Press `Ctrl-b Ctrl-b` to send the prefix to the inner one.

## Terminal and clipboard over SSH

Two smaller things make remote work feel local:

- **Terminal type.** Full-screen programs look up your terminal's capabilities (terminfo) using `$TERM`. A remote host may not know a newer terminal such as Ghostty, and vim and tmux then render badly. [config/ghostty/config.ghostty](../../config/ghostty/config.ghostty) turns on `ssh-terminfo`, which installs Ghostty's terminfo entry on the remote host at first connect, and `ssh-env`, which falls back to a widely known `TERM` and passes a few terminal variables along.
- **Clipboard.** tmux's `set -s set-clipboard on` uses the OSC 52 escape sequence. Text you copy in tmux copy mode on a remote host travels back through SSH to your Mac clipboard. Nothing needs to be installed on the host.

## Exercises

1. Run `ssh dev-01 true`, then `ls -l ~/.ssh/cm/`. You'll see the master's socket. Run `ssh -O check dev-01`, then `ssh -O exit dev-01`.
2. Time a cold and a warm `ssh dev-01 true` as shown above.
3. Run `task ubuntu`, start `top`, disconnect with `Ctrl-b d`, then run `task ubuntu` again. `top` is still running.
4. Inside that session, run `echo "$SSH_CONNECTION"` and check the status bar colour. Compare with a local `task main`.

**Next:** [5. Scripting over SSH](05-scripting.md)
