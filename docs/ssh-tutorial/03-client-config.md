# 3. The client config file

**Level:** intermediate · **Assumes:** [chapters 1–2](01-first-connection.md) · [Back to contents](README.md)

Typing `ssh -p 2222 -i ~/.ssh/lab_key alice@192.0.2.20` gets old fast, and it spreads an address through your shell history and scripts. `~/.ssh/config` lets you say `ssh dev-01` instead. This chapter explains how the file is read, because a few surprising rules decide which setting wins.

## A first `Host` block

```sshconfig
Host dev-01
    HostName 192.0.2.20
    User alice
    IdentityFile ~/.ssh/id_ed25519
```

- `Host` lists one or more **patterns**. The block applies when the name you typed matches one of them. `*` and `?` work as wildcards.
- `HostName` is the real address or DNS name to connect to.
- Every command that uses SSH now understands the alias: `ssh dev-01`, `scp file dev-01:/tmp/`, `rsync -a dir/ dev-01:dir/`, `git clone dev-01:repo.git`.

## Rule 1: the first value wins

This is the rule that confuses everyone. SSH reads the config from top to bottom, and **for each option it keeps the first value it finds** among the blocks that match. Later matches can add options that were not set yet, but they can't change ones that were.

So specific blocks go first and `Host *` defaults go last. The repo's shared file, [config/ssh/workbench.conf](../../config/ssh/workbench.conf), is built exactly that way:

```sshconfig
Host rhel-rhcsa01 dev-01 proxmox
    HostName %h
    ServerAliveInterval 30
    ServerAliveCountMax 4
    ControlMaster auto
    ControlPath ~/.ssh/cm/%C
    ControlPersist 10m
    StrictHostKeyChecking accept-new

Host *
    ForwardAgent no
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

`dev-01` matches **both** blocks. It gets `ServerAliveInterval 30` from the first block. The `60` in `Host *` is ignored for it, because a value was already set. It still gets `ForwardAgent no` from `Host *`, because nothing earlier set that option. Any other host, such as `github.com`, matches only `Host *` and gets `60`.

## Rule 2: see what SSH will actually do with `ssh -G`

Don't reason about precedence in your head. Ask SSH. `ssh -G` prints the final, merged configuration for a host **without connecting**:

```bash
mac$ ssh -G dev-01 | grep -E '^(hostname|user|port|serveraliveinterval|forwardagent|controlpath) '
```

`-F <file>` makes SSH read **only** that file instead of `~/.ssh/config`, which is a safe way to explore a config you haven't installed. Try it on the repo's file right now:

```bash
mac$ cd platform-workbench
mac$ ssh -G -F config/ssh/workbench.conf dev-01 | grep -E '^(hostname|serveraliveinterval|forwardagent|stricthostkeychecking) '
hostname dev-01
stricthostkeychecking accept-new
serveraliveinterval 30
forwardagent no
mac$ ssh -G -F config/ssh/workbench.conf github.com | grep '^serveraliveinterval'
serveraliveinterval 60
```

This repo relies on `ssh -G` in three places: `task lint` in [Taskfile.yml](../../Taskfile.yml), the offline tests in [scripts/test-remote.sh](../../scripts/test-remote.sh), and `verify` in [bootstrap/modules/ssh.sh](../../bootstrap/modules/ssh.sh). All of them check the *effective* settings rather than grepping the file:

```bash
value=$(ssh -G -F "$dir/config" "$host")
printf '%s\n' "$value" | grep -q '^forwardagent no$' && ok "$host agent forwarding off" || bad "$host agent forwarding is enabled"
```

## Tokens: `%h`, `%C` and friends

Some options accept tokens that SSH expands per connection:

| Token | Expands to |
|---|---|
| `%h` | The host name being connected to (after any `HostName` substitution) |
| `%n` | The name exactly as you typed it |
| `%r` | The remote user name |
| `%p` | The port |
| `%C` | A hash of the connection details (local host, remote host, port, user): short and unique |

`HostName %h` in the repo's config means "connect to the alias itself as a DNS name". With Tailscale MagicDNS, `dev-01` resolves to the machine of that name on your tailnet, so **no address appears anywhere in the file**. `%C` is used for socket paths in [chapter 4](04-sessions.md).

## Rule 3: `Include` lets you layer files

`Include` pulls other files in at that point. Globs are expanded in alphabetical order. The repo uses this to separate shared defaults from private details. The layout it creates on the Mac:

```text
~/.ssh/config                         # starts with: Include ~/.ssh/config.d/*.conf
~/.ssh/config.d/10-hosts.local.conf   # PRIVATE: User, IdentityFile, temporary HostName
~/.ssh/config.d/50-workbench.conf     # symlink to config/ssh/workbench.conf (public)
```

Combine this with rule 1 and you get a clean override system:

1. `10-hosts.local.conf` is read first, so **your private values win**.
2. `50-workbench.conf` fills in everything you didn't set.
3. Anything below the `Include` in `~/.ssh/config` comes last and can only fill gaps.

This is why the `ssh` module puts the `Include` at the very **top** of `~/.ssh/config` using a marker block (`--top`), and why `verify` checks line 1:

```bash
marker_block_set "$dir/config" ssh --top <<< 'Include ~/.ssh/config.d/*.conf'
```

The result at the top of your `~/.ssh/config`:

```sshconfig
# >>> platform-workbench ssh >>>
Include ~/.ssh/config.d/*.conf
# <<< platform-workbench ssh <<<
```

## Private values stay private

The shared file is public. Everything personal goes in the local file, which starts from [config/ssh/hosts.local.conf.example](../../config/ssh/hosts.local.conf.example):

```sshconfig
Host proxmox
    User root

# For first contact before Tailscale is available:
# Host rhel-rhcsa01
#     User myuser
#     HostName 192.0.2.10
```

Bootstrap copies the example once with mode `600`, and [.gitignore](../../.gitignore) ignores `*.local.conf`, so the real file can never be committed.

### Worked example: first contact, then MagicDNS

A brand-new VM isn't on the tailnet yet, so the alias can't resolve. Temporarily add an address in the **local** file:

```sshconfig
Host dev-01
    User alice
    HostName 192.0.2.20
```

Because `10-` is read before `50-`, this `HostName` beats `HostName %h`. Once the host has joined Tailscale, delete the `HostName` line. The alias falls through to `%h` and resolves by name. `User alice` keeps applying. [docs/new-machine.md](../new-machine.md) walks through this flow.

## Aliases must match the host registry

The repo keeps a registry of managed hosts in [bootstrap/hosts.conf](../../bootstrap/hosts.conf):

```text
rhel-rhcsa01    rhel
dev-01  ubuntu
proxmox     proxmox
```

[scripts/check-repo.sh](../../scripts/check-repo.sh) extracts the names from the `Host` line of `workbench.conf` and fails if the two lists differ, so a host can't be managed by the scripts without an SSH alias, or the other way round:

```bash
ssh_hosts=$(awk 'tolower($1)=="host" && $2!="*" {for (i=2; i<=NF; i++) print $i}' config/ssh/workbench.conf | sort)
```

## Exercises

Build a throwaway layered config in `/tmp` and use `ssh -G` to predict and confirm the results. Nothing here connects anywhere.

```bash
mac$ mkdir -p /tmp/sshplay/config.d
mac$ printf 'Include /tmp/sshplay/config.d/*.conf\n' > /tmp/sshplay/config
mac$ printf 'Host dev-01\n    User alice\n    HostName 192.0.2.20\n' > /tmp/sshplay/config.d/10-local.conf
mac$ cp config/ssh/workbench.conf /tmp/sshplay/config.d/50-workbench.conf
mac$ ssh -G -F /tmp/sshplay/config dev-01 | grep -E '^(user|hostname|serveraliveinterval) '
```

1. Before running the last line, predict the three values. Were you right?
2. Rename `10-local.conf` to `90-local.conf` and run it again. Which value changed, and why?
3. Add `Host *` with `ForwardAgent yes` to the local file at `10-`. What does `ssh -G` report for `forwardagent` now? (This is exactly what the repo's `verify` looks for.)
4. Clean up with `rm -rf /tmp/sshplay`.

**Next:** [4. Fast, durable sessions](04-sessions.md)
