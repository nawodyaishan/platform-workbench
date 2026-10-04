# 5. Scripting over SSH

**Level:** advanced · **Assumes:** [chapters 1–4](README.md), comfortable Bash · [Back to contents](README.md)

[scripts/remote.sh](../../scripts/remote.sh) bootstraps a Linux host from the Mac without the repository or any Git credential ever being on that host. It is a compact catalogue of SSH scripting techniques. This chapter takes it apart.

## Two shells, two rounds of expansion

When you run `ssh host "command"`, **two** shells process the text: your local shell first, then the remote user's shell. The quoting decides which one expands what:

```bash
mac$ ssh dev-01 "echo $HOME"    # double quotes: expanded locally  -> /Users/alice
mac$ ssh dev-01 'echo $HOME'    # single quotes: expanded remotely -> /home/alice
```

`ssh` joins all its arguments into one string and hands it to the remote shell, so `ssh host ls -l "my file"` does **not** keep your quoting. The remote shell sees `ls -l my file`. When in doubt, pass exactly one single-quoted string.

### The repo's trick with `~`

```bash
REMOTE_DIR='~/.local/share/platform-workbench'  # expanded by the remote shell
ssh "$host" "cat $REMOTE_DIR/.source-commit 2>/dev/null || true"
```

The single quotes stop the local shell from turning `~` into `/Users/alice`. Inside the double-quoted command, `$REMOTE_DIR` is expanded locally, but a `~` that comes out of a variable expansion is not tilde-expanded again. So the literal `~/.local/…` reaches the remote shell, which expands it to `/home/alice/.local/…`. One variable, correct on both sides.

## Never build commands from untrusted input

Anything you put into a remote command string is **code** for the remote shell. A "host name" such as `x; rm -rf ~` would be a disaster. `remote.sh` validates everything before it goes near `ssh`:

```bash
case "$host" in *[!A-Za-z0-9._-]*) die "invalid host alias: $host" ;; esac
profile=$(host_profile "$host") || die "HOST must be listed in bootstrap/hosts.conf ..."
```

```bash
case "$arg" in
  --dry-run|--yes) ;;
  --profile|--force-profile|--expect-host) die "remote controls $arg" ;;
  *) case "$arg" in *[!a-zA-Z0-9_,.-]*|'') die "unsafe workbench argument: $arg" ;; esac ;;
esac
```

The rules to copy:

1. **Allowlist characters.** Don't try to escape dangerous characters. Reject anything outside a known-safe set.
2. **Allowlist values.** The host must also be in the registry, not just look like a host name.
3. **Keep control flags local.** The profile comes from the registry, never from the caller.

## Stream data through stdin: no `scp` needed

`ssh` connects your local stdin to the remote command's stdin. That turns any pipe into a network transfer. The payload function in `remote.sh`:

```bash
payload() { git ls-files -z -- bootstrap config kodekloud | tar --null -T - -czf -; }

payload | ssh "$host" "tar -xzf - -C $REMOTE_DIR.new"
```

- `git ls-files -z` lists **only tracked files**, NUL-separated so spaces in names are safe. Untracked files, including a stray private key or `*.local.conf`, are never sent.
- `tar … -czf -` writes a compressed archive to stdout. `tar -xzf -` on the far side reads it from stdin.
- There's no temporary archive and no second tool, and it works through multiplexing.

The same idea handles one-line transfers:

```bash
mac$ ssh dev-01 'cat > /tmp/notes.txt' < notes.txt         # upload
mac$ ssh dev-01 'cat /etc/os-release' > os-release.txt     # download
mac$ ssh dev-01 "cat ~/.ssh/id_ed25519_github_dev-01.pub"  # read a value into a script
```

For everyday copying, `scp` and `rsync` use the same aliases and config:

```bash
mac$ scp ./file.txt dev-01:/tmp/
mac$ rsync -av --delete ./site/ dev-01:site/
```

## Run a local script remotely with a heredoc

To run several lines remotely without copying a script file, feed the script on stdin to `bash -s`. From the `gh-key` part of `remote.sh`:

```bash
ssh "$host" "bash -s -- $host" <<'REMOTE'
set -eu
umask 077
config=$HOME/.ssh/config
...
sed -i.bak "s/id_ed25519_github_HOST/id_ed25519_github_$1/" "$tmp"
REMOTE
```

- `bash -s` reads the script from stdin. Everything after `--` becomes `$1`, `$2`, … inside it.
- `<<'REMOTE'`: the **quoted** delimiter turns off local expansion, so `$HOME` and `$1` are expanded by the remote bash. With an unquoted `<<REMOTE`, your local shell would expand them first.
- Values go in as positional arguments (`$1`), not pasted into the script text. The value is already validated, and the script stays constant.

## Publish atomically, keep a rollback

A half-copied directory is worse than none. `remote.sh` stages, then swaps:

```bash
ssh "$host" "set -eu; umask 077; mkdir -p ~/.local/share; rm -rf $REMOTE_DIR.new; mkdir $REMOTE_DIR.new"
payload | ssh "$host" "tar -xzf - -C $REMOTE_DIR.new"
source_stamp | ssh "$host" "cat > $REMOTE_DIR.new/.source-commit"
ssh "$host" "set -eu; rm -rf $REMOTE_DIR.prev; if [ -d $REMOTE_DIR ]; then mv $REMOTE_DIR $REMOTE_DIR.prev; fi; mv $REMOTE_DIR.new $REMOTE_DIR"
```

1. Extract into `.new`. If anything fails, `set -e` in the caller stops before the swap.
2. Record a stamp (Git commit plus payload checksum), so `verify` can later warn when the host runs different code from your checkout.
3. Swap with two `mv`s. The previous version survives as `.prev` for a manual rollback.

Thanks to multiplexing ([chapter 4](04-sessions.md)), these four `ssh` calls cost one login.

## Interactive vs non-interactive calls

| Situation | Flags | Example in the repo |
|---|---|---|
| Health check, must never prompt | `-o BatchMode=yes -o ConnectTimeout=5` | `task hosts` |
| Plain command, output captured | none | reading the public key in `gh-key` |
| Needs a terminal (prompts, sudo, colours, tmux) | `-t` | `ssh-keygen` passphrase prompt, the final `workbench.sh` run |
| Data on stdin | **no** `-t` | the payload pipe |

`-t` and piped stdin don't mix well, so the repo uses separate `ssh` calls for streaming and for interactive steps. The last call uses `exec ssh -t …`, so the remote exit code becomes the script's exit code.

## Test SSH automation without a host

[scripts/test-remote.sh](../../scripts/test-remote.sh) tests the whole flow offline. The core trick is a **stub `ssh`** placed first on `PATH` that only logs its arguments:

```bash
cat > "$tmp/ssh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$WB_TEST_LOG"
STUB
chmod +x "$tmp/ssh"
PATH="$tmp:$PATH" task ssh HOST="$host"
grep -q "^-t $host .*tmux new-session -A -s main" "$WB_TEST_LOG"
```

It also proves the security properties:

- It creates an untracked `id_ed25519_test_*` file and a `*.local.conf` inside `config/ssh/`, then checks they are **absent** from the payload.
- It checks that an unregistered host and a caller-supplied `--profile` are refused, and that dry runs never reach `ssh` at all (the log must stay empty).

Run it with `task test:remote`.

## Exercises

1. Predict, then run: `ssh dev-01 "echo $USER"` and `ssh dev-01 'echo $USER'`.
2. Copy a directory with `tar -czf - dir | ssh dev-01 'tar -xzf - -C /tmp'`, and compare the time with `scp -r`.
3. Write a heredoc that prints the remote host name and the first argument: `ssh dev-01 'bash -s -- hello' <<'EOF'` … `EOF`. Then try it with an unquoted `<<EOF` and a `$HOSTNAME` inside. What changed?
4. Read `scripts/remote.sh payload | tar -tzf - | head` to see exactly what a remote host would receive.

**Next:** [6. Security and hardening](06-security.md)
