# platform-workbench: agent notes

A public, profile-driven Bash toolkit that bootstraps, updates and verifies a macOS workstation and its Linux lab hosts. Start with [README.md](README.md) and [docs/](docs/).

## Rules

- Public repository. Never add secrets, private keys, tokens, real IPs, tailnet names, hostnames of real machines, kubeconfigs, Terraform state or personal notes. Use `192.0.2.0/24` and `example.com` in examples. Run `task secrets` before committing.
- Bash must run on macOS `/bin/bash` 3.2: no associative arrays, `mapfile` or `${var,,}`. Expand possibly-empty arrays with `${arr[@]+"${arr[@]}"}`.
- Modules define `<name>_bootstrap`, `<name>_update` and `<name>_verify`. Bootstrap/update are idempotent and honour `--dry-run` (`is_dry_run`/`dry_note`); verify is read-only.
- Edit user files only through marker blocks (`marker_block_set`) or symlinks (`link_file`), which back up first. Call `marker_block_set` with a here-string, not a pipe, so result counters survive.
- One canonical file per tool under `config/`. Do not add a second aliases, tmux or Vim config.
- A new host needs matching entries in `bootstrap/hosts.conf` and the `Host` line of `config/ssh/workbench.conf`.
- Keep Proxmox minimal: no dev stacks, no Kubernetes, no `pve-*` upgrades.

## Validate

```bash
task check          # lint + secrets + repo (links, registry, duplicates)
task test:remote    # offline remote-flow tests
task test:profiles  # container smoke tests (needs docker)
```
