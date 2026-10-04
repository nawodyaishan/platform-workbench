# Tasks: Ubuntu full-stack dev stack

Reads `spec.md` and `plan.md` (both drafted 2026-10-04). Specialist assignment: none beyond `plan.md`. There are no task-specific exceptions.

## Task list

| ID | Task | Depends on | Verification |
|---|---|---|---|
| T1 | `workbench.sh`: add `--only a,b,c` (filter `MODULES` in profile order; unknown or out-of-profile name is a usage error), new defaults (`PKGS_DEV`, `NVM_VERSION`, `JAVA_MAJOR`), die on `--extras devstack` outside `ubuntu`, source new `lib/install.sh`. Update the usage header. | — | `bash -n`; shellcheck; `workbench.sh verify --profile ubuntu --only nope` exits 2 |
| T2 | Create `bootstrap/lib/install.sh` with `go_install_tarball <version>` (moved from `lang.sh`'s `_go_install`) and `sha256_file`. `lang.sh` calls it and defers Go and Node to devstack when `extra_on devstack`. | T1 | `task test:profiles -- ubuntu` still passes (no behavior change without the extra) |
| T3 | `devstack.sh` part 1: gating, apt build-deps and CLIs, the `_ds_apt_repo` fingerprint helper, HashiCorp, Adoptium and GitHub CLI repos, `terraform`, `temurin-$JAVA_MAJOR-jdk`, `maven`, `gh`. Bootstrap, update and verify for each. | T1 | `bash -n`; shellcheck |
| T4 | `devstack.sh` part 2: Go latest, nvm + Node LTS + default alias, corepack + pnpm + `corepack enable yarn`, rustup + stable, kind (checksum), AWS CLI v2, Homebrew. Bootstrap, update and verify for each. Re-check the nvm tag and the three key fingerprints against the vendor pages. | T2, T3 | `bash -n`; shellcheck |
| T5 | `profiles/ubuntu.sh` (`MODULES += devstack`, `NVM_VERSION`, `JAVA_MAJOR`, `PKGS_DEV`); `config/shell/bashrc` (cargo PATH, `brew shellenv`). | T3, T4 | `task lint` (bashrc parses; aliases guard check unchanged) |
| T6 | `Taskfile.yml`: `devstack`, `devstack:update` and `devstack:verify` plus help text. `Makefile`: `devstack`, `devstack-update` and `devstack-verify` plus `.PHONY`. | T1 | `task --list` shows them; `make help` lists them; `task test:remote` |
| T7 | `scripts/test-profiles.sh`: opt-in `ubuntu-devstack` case (image `ubuntu:24.04`, runs with `--extras devstack --only base,containers,k8s,devstack`, longer timeout, asserts `IDEMPOTENT` and that `node`, `go`, `rustc`, `java`, `terraform`, `aws`, `brew`, `pnpm` and `yarn` resolve for the tester user). `scripts/test-remote.sh`: an `--only` argument passes the safety filter. | T5, T6 | `task test:profiles -- ubuntu ubuntu-devstack`; `task test:remote` |
| T8 | Docs: `docs/hosts.md` (Extras: `devstack`; a short "Full-stack dev stack" section with the tool table, trust assumptions and the Node 26 LTS note), `README.md` (ubuntu row, commands table, flags line). | T6 | `task repo` (link check) |
| T9 | Final: `task check`, `task test:remote`, `task test:profiles -- ubuntu ubuntu-devstack`; record results here. | T1–T8 | All exit 0 |

## Batches

### Batch 1: engine, module and commands

- Tasks: T1, T2, T3, T4, T5, T6
- Outcome: `task devstack[-:update|:verify]` exists and the module is complete. A plain ubuntu run is unchanged.
- Verification: `task check`; `task test:remote`; `task test:profiles -- ubuntu` (regression).
- State: **not started**
- Next action: waiting for the combined approval in `spec.md`.

### Batch 2: container proof and docs

- Tasks: T7, T8, T9
- Outcome: an end-to-end idempotency proof in a throwaway Ubuntu 24.04 container, plus user docs.
- Verification: T9.
- State: **not started**
- Next action: after Batch 1 human review.

Not in any batch: a real run on `dev-01` (`task devstack` on the host, or `task bootstrap HOST=dev-01 -- --extras devstack --only base,containers,k8s,devstack`). It needs separate, explicit human authorization when it happens.

## Approval and continuation

Combined approval is recorded in `spec.md` §Approval. Status: **draft/pending**.
