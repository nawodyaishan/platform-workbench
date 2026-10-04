# 6. Security and hardening

**Level:** advanced · **Assumes:** [chapters 1–5](README.md) · [Back to contents](README.md)

SSH is secure by default, but a few popular settings quietly undo that. This chapter covers the decisions behind the repo's defaults and how to harden the server side safely.

## The threat model in one table

| You want to prevent | Repo defence | Where |
|---|---|---|
| A compromised host using your identity elsewhere | `ForwardAgent no`; a separate key per host | [workbench.conf](../../config/ssh/workbench.conf), [remote.sh](../../scripts/remote.sh) `gh-key` |
| Talking to an impostor server | `StrictHostKeyChecking accept-new`, never `no` | workbench.conf, `verify` |
| Password guessing | Key login, then password login disabled by you | this chapter |
| Port 22 exposed to the internet | Hosts reached over Tailscale | [tailscale.sh](../../bootstrap/modules/tailscale.sh) |
| Keys or addresses leaking through Git | `.gitignore`, `task secrets`, a tracked-files-only payload | [check-secrets.sh](../../scripts/check-secrets.sh), [test-remote.sh](../../scripts/test-remote.sh) |

## Agent forwarding: convenient and dangerous

`ssh -A` (or `ForwardAgent yes`) lets the remote host use **your local agent** to authenticate onward, for example to run `git clone` from GitHub on a VM with your laptop's key. The catch: while you're connected, **anyone with root on that host**, or with access to your account there, can use the forwarded agent socket to log in wherever your keys work. They can't copy the key, but they don't need to.

The repo turns it off for everything:

```sshconfig
Host *
    ForwardAgent no
```

`verify` fails if any config re-enables it, or disables host key checking:

```bash
if grep -Ei '^[[:space:]]*(ForwardAgent[[:space:]]+yes|StrictHostKeyChecking[[:space:]]+no)' "$dir/config" "$dir/config.d/"*.conf 2>/dev/null; then
  bad "unsafe SSH setting present"
```

When you really need it once, use `ssh -A dev-01` for that session on a host you trust, and log out afterwards. For lasting access, give the host its own key (next section). To hop through a host, use `ProxyJump` instead ([chapter 7](07-tunnels-and-jumps.md)), which never exposes your agent to the middle host.

## One key per host and purpose

If a lab VM needs to pull from GitHub, give it **its own** key. If the VM is compromised, you revoke one key, and your laptop key is never involved. `task gh-key HOST=dev-01` automates this. The steps in [scripts/remote.sh](../../scripts/remote.sh):

1. **Ask first.** Nothing happens without a `y`.
2. **Create the key on the host**, so the private half is born there and never travels:

   ```bash
   ssh -t "$host" "umask 077; mkdir -p ~/.ssh; test ! -e ~/.ssh/id_ed25519_github_${host} || { echo 'key already exists'; exit 1; }; ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_github_${host} -C '${host} platform-workbench'"
   ```

3. **Pin it for GitHub only** in the host's `~/.ssh/config`, backing up the file first:

   ```sshconfig
   # >>> platform-workbench github >>>
   Host github.com
       IdentityFile ~/.ssh/id_ed25519_github_dev-01
       IdentitiesOnly yes
       ForwardAgent no
   # <<< platform-workbench github <<<
   ```

   `IdentitiesOnly yes` means offer only this key to GitHub, even if an agent holds others. This avoids both the wrong account being picked and "Too many authentication failures".
4. **Show only the public half** and ask again before publishing it with `gh ssh-key add`.

Test it from the host. GitHub's SSH user is always `git`, and `-l git` is the same as writing `git` before the `@`:

```bash
dev-01$ ssh -T -l git github.com
```

Revoke it any time from the Mac with `gh ssh-key list` and `gh ssh-key delete <id>`. When the host needs only one repository, a **read-only deploy key** on that repository is narrower still.

## Host key policy

Recap from [chapter 1](01-first-connection.md): `accept-new` learns new hosts but refuses changed keys. Two anti-patterns to avoid:

- `StrictHostKeyChecking no` plus `UserKnownHostsFile /dev/null` is common in copy-pasted scripts. It disables the only protection against an impostor server.
- Deleting `~/.ssh/known_hosts` to make a warning go away throws away every host you've verified.

When a key has genuinely changed (for example after a reinstall), remove just that entry and reconnect: `ssh-keygen -R dev-01`.

## Harden the server (`sshd`)

The repo installs and enables `sshd` but deliberately doesn't change how it authenticates. That's a decision to make yourself, carefully.

### 1. Keep a way back in

Before touching `sshd`, open **two** SSH sessions to the host, or have the VM console ready. The second session is your lifeline if the new config locks you out. Existing sessions survive a reload.

### 2. Prove key login first

```bash
mac$ ssh -o ControlPath=none -o PasswordAuthentication=no -o BatchMode=yes dev-01 true && echo ok
```

`ControlPath=none` bypasses any running multiplexing master ([chapter 4](04-sessions.md)). Without it, a master that is already authenticated would make the test pass without checking anything.

### 3. Add a drop-in file that wins

Modern Ubuntu and RHEL 9 read `/etc/ssh/sshd_config.d/*.conf` near the top of `sshd_config`. Like the client, **`sshd` keeps the first value it sees**. Drop-ins are read in name order, and some images ship `50-cloud-init.conf` with `PasswordAuthentication yes`, so use a lower number:

```bash
dev-01$ sudo tee /etc/ssh/sshd_config.d/10-hardening.conf >/dev/null <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
EOF
```

`prohibit-password` still allows root with a key. That matters on Proxmox, which runs as root and uses root SSH keys between cluster nodes. On a normal VM you can use `PermitRootLogin no`.

### 4. Check, then reload

```bash
dev-01$ sudo sshd -t                                                  # syntax check; silent means OK
dev-01$ sudo sshd -T | grep -Ei '^(passwordauthentication|kbdinteractiveauthentication|permitrootlogin) '
dev-01$ sudo systemctl reload ssh        # "sshd" on RHEL; the repo's _sshd_unit picks the right one
```

`sshd -T` prints the **effective** server config, the server-side twin of `ssh -G`. Now test a **new** connection from the Mac (`ssh -o ControlPath=none dev-01`) while your lifeline session is still open.

> [!NOTE]
> Recent Ubuntu releases start `sshd` through socket activation (`ssh.socket`). Authentication settings apply after a reload or restart of `ssh`, but changing `Port` or `ListenAddress` also needs the socket unit updated. Keep the default port and use Tailscale instead of hiding the port.

## Keep secrets out of Git

A public repo about SSH has to be careful about what it publishes:

- **Ignored by default.** [.gitignore](../../.gitignore) covers private key names (`id_ed25519*`, `id_rsa*`, `id_ecdsa*`, keeping `!*.pub`), `*.pem`, `*.key` and `*.local.conf`.
- **Scanned before commit.** [scripts/check-secrets.sh](../../scripts/check-secrets.sh) rejects sensitive file names, private key headers, private and Tailscale IP ranges, `*.ts.net` tailnet names and personal email addresses. Examples in this repo use `192.0.2.0/24` and `example.com`, which are reserved for documentation.
- **Scanned before sending.** `remote.sh` runs the secret scan before any payload leaves the Mac.
- **Only tracked files leave.** The payload is built from `git ls-files`, and `task test:remote` proves untracked key files are excluded.

## Key hygiene checklist

- A passphrase on every personal key. Use the agent for convenience.
- One key per device, and one per host that needs outbound access. Never a shared key.
- Review `~/.ssh/authorized_keys` on each host now and then, and delete keys you don't recognise.
- Review `gh ssh-key list` and delete keys for machines you no longer use.
- Ed25519 for new keys.

## Exercises

1. Run `ssh -G dev-01 | grep -E '^(forwardagent|stricthostkeychecking) '` and explain each value from the files in [chapter 3](03-client-config.md).
2. On a lab VM, with a lifeline session open, apply the hardening drop-in, verify with `sshd -T`, and test a new login.
3. From the Mac, confirm the password fallback is gone: `ssh -o ControlPath=none -o PubkeyAuthentication=no dev-01` should now be refused with `Permission denied`.
4. Run `task secrets` and read the list of patterns in `scripts/check-secrets.sh`.

**Next:** [7. Tunnels and jump hosts](07-tunnels-and-jumps.md)
