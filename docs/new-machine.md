# Bootstrapping a machine

## A fresh Linux host, driven from the Mac

The remote host never needs a clone of this repository or any Git credential. `scripts/remote.sh` streams the Git-tracked `bootstrap/`, `config/` and `kodekloud/` files over SSH to `~/.local/share/platform-workbench`. It keeps the previous copy as `.prev` and runs the lifecycle engine there. Your Mac private key never leaves the Mac.

1. **On the new host:** install the OS, create your normal sudo user (root on Proxmox), and make sure `sshd` is running.
2. **First contact (Mac):** until MagicDNS works, add a temporary address under the alias in the untracked `~/.ssh/config.d/10-hosts.local.conf`:

   ```sshconfig
   Host ubuntu-lab
       HostName 192.0.2.20
       User alice
   ```

3. **Install your public key only:** `task ssh:copy-id HOST=ubuntu-lab` (add `KEY=~/.ssh/id_ed25519.pub` to pick a specific key).
4. **Review, then apply:** run `task bootstrap HOST=ubuntu-lab -- --dry-run`, read the plan, then run `task bootstrap HOST=ubuntu-lab`. The Mac runs `task secrets` before sending anything.
5. **Join the tailnet (on the host):** run `sudo tailscale up` interactively. Auth keys never go in Git. Name the machine after its alias so `verify` can confirm the tailnet hostname.
6. **Remove the temporary override:** delete the `HostName` line so the alias resolves through MagicDNS.
7. **Verify:** run `task verify HOST=ubuntu-lab`, then `task ubuntu`. Use `task update HOST=ubuntu-lab` for later managed updates.

If the host later needs its own GitHub access, run `task gh-key HOST=ubuntu-lab`. It creates a separate key on the host, shows only the public half, and asks again before publishing it with `gh`. Revoke it independently with `gh ssh-key list` / `gh ssh-key delete <id>`. A read-only deploy key is better when one repository is enough.

## A Linux host running the toolkit itself

Because the repository is public, a host can also clone it over HTTPS with no credentials and run the engine locally:

```bash
git clone https://github.com/nawodyaishan/platform-workbench.git ~/platform-workbench
~/platform-workbench/bootstrap/workbench.sh bootstrap --profile ubuntu --dry-run
~/platform-workbench/bootstrap/workbench.sh bootstrap --profile ubuntu
```

Pick one path per host. The Mac-driven payload is the default because it keeps every host on the Mac's reviewed revision.

## A new Mac

1. Install the Xcode command line tools, [Homebrew](https://brew.sh), and `go-task` (`brew install go-task`).
2. Clone this repository, then run `task bootstrap -- --dry-run`, review it, and run `task bootstrap`.
3. Install the GUI apps yourself: Ghostty, Tailscale, OrbStack.
4. Set your Git identity: `git config --global user.name …` and `git config --global user.email …`. The managed gitconfig deliberately has none.
5. Put per-host `User`/`IdentityFile` values in `~/.ssh/config.d/10-hosts.local.conf`, which bootstrap creates from the example.
6. Run `task verify`.

## What bootstrap, update and verify mean

| Verb | Effect |
|---|---|
| `bootstrap` | Install and wire everything the profile lists. It is idempotent, so it is also the repair path. Existing files are backed up to `~/.platform-workbench-backup/<timestamp>/` before replacement. |
| `update` | Upgrade only the packages this profile manages (never a full system upgrade), then re-apply the wiring. |
| `verify` | Read-only. Exits 1 if any check fails. |

Machines set up by the earlier `ops-workbench` toolkit are migrated automatically. The next `bootstrap` or `update` replaces its rc-file and `~/.ssh/config` marker blocks and drops its Git include. `verify` reports anything left over, including an old `~/.local/share/ops-workbench` payload you can delete by hand.
