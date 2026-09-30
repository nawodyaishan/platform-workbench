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

## Spec-driven development

The agentic SDD skills live in `.claude/skills/agentic-sdd-*`. Start with `agentic-sdd-router`. The shared policy is in `.claude/skills/agentic-sdd-router/references/workflow-policy.md`.

- Canonical sources: [README.md](README.md) and [docs/](docs/). There is no separate SRS or roadmap.
- Features: `specs/<nnn-slug>/` holds `spec.md`, `plan.md` and `tasks.md`. The single combined human approval of all three is recorded in the `## Approval` section of `spec.md`.
- Batch state and continuation notes: `tasks.md` of the feature.
- Development versus execution: editing `bootstrap/`, `config/` or `scripts/`, running the checks below, and `--dry-run` or `verify` against the local machine are development. Running `task bootstrap|update` without `--dry-run`, anything with `HOST=`, `task ssh:copy-id` and `task gh-key` act on real machines and need explicit human authorization every time.

## Validate

```bash
task check          # lint + secrets + repo (links, registry, duplicates)
task test:remote    # offline remote-flow tests
task test:profiles  # container smoke tests (needs docker)
```
