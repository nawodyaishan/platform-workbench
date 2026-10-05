# Tasks: Ubuntu full-stack dev stack

Reads `spec.md` and `plan.md` (both drafted 2026-10-04). Specialist assignment: none beyond `plan.md`. There are no task-specific exceptions.

## Task list

| ID | Task | Depends on | Verification |
|---|---|---|---|
| T1 | `workbench.sh`: add `--only a,b,c` (filter `MODULES` in profile order; unknown or out-of-profile name is a usage error), new defaults (`PKGS_DEV`, `NVM_VERSION`, `JAVA_MAJOR`), die on `--extras devstack` outside `ubuntu`, source new `lib/install.sh`. Update the usage header. | — | `bash -n`; shellcheck; `workbench.sh verify --profile ubuntu --only nope` exits 2 |
| T2 | Create `bootstrap/lib/install.sh` with `go_install_tarball <version>` (moved from `lang.sh`'s `_go_install`) and `sha256_file`. `lang.sh` calls it and defers Go and Node to devstack when `extra_on devstack`. | T1 | `task test:profiles -- ubuntu` still passes (no behavior change without the extra) |
| T3 | `devstack.sh` part 1: gating, apt build-deps and CLIs, the `_ds_apt_repo` fingerprint helper, HashiCorp, Adoptium and GitHub CLI repos, `terraform`, `temurin-$JAVA_MAJOR-jdk`, `maven`, `gh`. Bootstrap, update and verify for each. | T1 | `bash -n`; shellcheck |
| T4 | `devstack.sh` part 2: Go latest, nvm + Node LTS + default alias, corepack (ships the yarn and pnpm shims), rustup + stable, kind (checksum), AWS CLI v2, Homebrew. Bootstrap, update and verify for each. Re-check the nvm tag and the three key fingerprints against the vendor pages. | T2, T3 | `bash -n`; shellcheck |
| T5 | `profiles/ubuntu.sh` (`MODULES += devstack`, `NVM_VERSION`, `JAVA_MAJOR`, `PKGS_DEV`); `config/shell/bashrc` (cargo PATH, `brew shellenv`). | T3, T4 | `task lint` (bashrc parses; aliases guard check unchanged) |
| T6 | `Taskfile.yml`: `devstack`, `devstack:update` and `devstack:verify` plus help text. `Makefile`: `devstack`, `devstack-update` and `devstack-verify` plus `.PHONY`. | T1 | `task --list` shows them; `make help` lists them; `task test:remote` |
| T7 | `scripts/test-profiles.sh`: opt-in `ubuntu-devstack` case (image `ubuntu:24.04`, runs with `--extras devstack --only base,shell,containers,k8s,devstack`, longer timeout, asserts `IDEMPOTENT` and that `node`, `go`, `rustc`, `java`, `terraform`, `aws`, `brew`, `pnpm` and `yarn` resolve for the tester user). `scripts/test-remote.sh`: an `--only` argument passes the safety filter. | T5, T6 | `task test:profiles -- ubuntu ubuntu-devstack`; `task test:remote` |
| T8 | Docs: `docs/hosts.md` (Extras: `devstack`; a short "Full-stack dev stack" section with the tool table, trust assumptions and the Node 26 LTS note), `README.md` (ubuntu row, commands table, flags line). | T6 | `task repo` (link check) |
| T9 | Final: `task check`, `task test:remote`, `task test:profiles -- ubuntu ubuntu-devstack`; record results here. | T1–T8 | All exit 0 (done 2026-10-05, see Batch 2) |

## Batches

### Batch 1: engine, module and commands

- Tasks: T1, T2, T3, T4, T5, T6
- Outcome: `task devstack[-:update|:verify]` exists and the module is complete. A plain ubuntu run is unchanged.
- Verification: `task check`; `task test:remote`; `task test:profiles -- ubuntu` (regression).
- State: **done** (reviewed and accepted by nawodyaishan, chat, 2026-10-05, "proceed")

#### Batch 1 implementation notes (2026-10-04)

- **HashiCorp key rotation.** The live key is `D55C0D1AC78A8D8126CB631CFC9CA96ACA026560` (rotated 2026-09-10, HCSEC-2026-33), not the `798AEC65…` in the drafted plan. `plan.md` is amended.
- **GitHub CLI keyring holds two primary keys** (`2C61…5716059`, expired, and `7F38…62313325`). The helper takes a list and requires every primary key in the file to be pinned.
- **Generic helper.** The repo helper is `apt_repo_keyed` in `bootstrap/lib/install.sh` (not `_ds_apt_repo` in the module), next to `go_install_tarball` and `sha256_file`. It handles both armored and binary keys.
- **Deviation from the spec scope table (pnpm).** The spec says `npm install -g corepack pnpm`, then `corepack enable yarn`. The corepack npm package (0.36.0) ships its own `pnpm`, `pnpx`, `yarn` and `yarnpkg` bins, so installing the `pnpm` package as well conflicts on `pnpm`/`pnpx`. The module installs only `corepack`; its shims provide both yarn and pnpm, and bootstrap caches the default versions once so verify runs offline. Accepted 2026-10-05.
- **Verify layout.** Verify is one read-only `devstack_verify` with a small `_ds_check` helper, not one `_ds_<tool>_verify` per tool.
- **Deviation: `shell` added to the module list.** The commands run `--only base,shell,containers,k8s,devstack`, not `base,containers,k8s,devstack`. Without `shell`, a fresh host that only runs `task devstack` never sources `config/shell/bashrc`, so node, go, cargo and brew are missing from new shells (seen in the container run). `shell` only writes its marker block and the tmux/vim links. Accepted 2026-10-05; spec, plan and T7 updated.
- **Engine hint.** After a run the "verify with:" hint now repeats `--extras`/`--only`.
- **Bug found by the container run and fixed:** `nvm version default` exits non-zero when no default exists, so Node was reported `ok` and never installed. Detection now accepts only a `v*` result.

#### Batch 1 verification results

- `bash -n` and shellcheck (repo lint level): pass.
- `workbench.sh verify --profile ubuntu --only nope`: exit 2. `--extras devstack` on `macos`: refused.
- `task check`: pass. `task test:remote`: pass.
- `task test:profiles -- ubuntu` (regression): PASS, IDEMPOTENT, devstack `n/a`.
- Ad-hoc throwaway `ubuntu:24.04` container run of `--extras devstack --only base,shell,containers,k8s,devstack` (preview of T7): native `linux/arm64`, final code: dry-run lists 20 changes and makes none; bootstrap `changed=24 fail=0`; verify `ok=76 fail=0`; rerun `changed=0` (IDEMPOTENT); node v24.21.0, npm, yarn, pnpm, go1.27.1, rustc, cargo, java (Temurin 25), mvn, terraform, aws-cli 2.37.9, gh, kind v0.33.0 and brew all resolve in a fresh login shell. An earlier amd64 (emulated) run got through every apt repo and binary install before hitting the nvm bug above. This is not a substitute for T7's harness case.

### Batch 2: container proof and docs

- Tasks: T7, T8, T9
- Outcome: an end-to-end idempotency proof in a throwaway Ubuntu 24.04 container, plus user docs.
- Verification: T9.
- State: **done**, awaiting final human review
- Next action: human review of Batch 2, then commits. A real run on `dev-01` still needs its own authorization.

#### Batch 2 notes and results (2026-10-05)

- T7: `scripts/test-profiles.sh` gains the opt-in `ubuntu-devstack` case (2700 s limit) asserting `IDEMPOTENT`, `LEGACY-MIGRATED` and `DEVSTACK-ON-PATH` (node, npm, yarn, pnpm, go, rustc, cargo, java, mvn, terraform, aws, gh, kind, brew, docker, kubectl and helm resolve in a new login shell). `scripts/test-remote.sh` checks that `--extras devstack --only …` passes `remote.sh`'s filter in a dry-run without SSH and that `--only=LIST` is refused. `remote.sh` dry-run now prints the forwarded `args:`.
- T8: `docs/hosts.md` (Extras, `--only`, "Full-stack dev toolchain (Ubuntu)" with tools, trust, key rotation, Node 26 LTS, remote use) and `README.md` (ubuntu row, commands, flags, layout, quality gates).
- Limitation, documented: remote `verify` accepts no flags, so `task verify HOST=dev-01` shows devstack as `n/a`; check the stack on the host with `task devstack:verify`. The remote payload is tracked files only, so a remote run needs the work committed first.
- T9 results: `task check` pass; `task test:remote` pass; `task test:profiles` (rhel, ubuntu, proxmox) all PASS and IDEMPOTENT; `task test:profiles -- ubuntu-devstack` PASS (native arm64 `ubuntu:24.04`, about 4 minutes): dry-run `changed=26` with no changes made, bootstrap `changed=25 fail=0`, verify `ok=76 fail=0`, rerun `changed=0`, DEVSTACK-ON-PATH.

### Batch 3: agentic-sdd skills (amendment 2)

- Tasks: T10 `devstack.sh` builds the agentic-sdd CLI from `AGENTIC_SDD_VERSION` (tag) checked against `AGENTIC_SDD_COMMIT`, then previews and applies only when something differs (a no-op apply still writes a log); verify checks the version and that preview is all `up to date` (`install` lines are `FAIL`, `replace` lines are `WARN`). T11 container case asserts the binary is on `PATH` and `agentic-sdd-router/SKILL.md` exists in all four client directories. T12 docs.
- Notes: the release only ships `darwin_all`, and the module path `agentic-sdd` is not `go install`-able, hence the source build. It needs no module downloads (no dependencies) and runs with `GOTOOLCHAIN=local`.
- Results: `task check` and `task test:remote` pass. `task test:profiles -- ubuntu-devstack` PASS: dry-run shows the build and apply steps; bootstrap `changed=27 fail=0`; verify `ok=78 fail=0` (`agentic-sdd 0.3.0`, skills up to date); rerun `changed=0`; `AGENTIC-SDD-SKILLS-OK`.
- Field note: nawodyaishan ran the Batch 1–2 command on their own Ubuntu 26.04 host (2026-10-05): `ok=22 fail=0`. `rust` reported "not found" there because Rust has no `rust` command (`rustc`, `cargo` and `rustup` are the binaries); no change needed.
- State: **awaiting human review**
- Next action: human review, then commit.

### Batch 4: devstack owns pnpm (amendment 3)

- Tasks: T13 `devstack.sh` `_ds_pnpm`: create `$PNPM_HOME/bin`, remove a `# pnpm` … `# pnpm end` block from `~/.bashrc` after `backup_copy`, and warn about standalone binaries in `$PNPM_HOME/bin`; verify reports the same. T14 `config/shell/bashrc` exports `PNPM_HOME` and adds `$PNPM_HOME/bin` to the only-if-present `PATH` loop (nvm still comes first). T15 container case seeds a standalone pnpm block and binary, then asserts the block is gone and a new login shell runs the nvm pnpm with `pnpm bin -g` = `~/.local/share/pnpm/bin`. T16 docs.
- Notes: a reproduction in an `ubuntu:26.04` container shows an interactive shell finds the corepack `pnpm` after devstack, while a non-interactive login shell (`bash -lc`) does not, because the wiring loads only in interactive shells. The host's earlier run reported `corepack yarn/pnpm shims` ok. So the "pnpm not found" was most likely a shell opened before nvm was installed; the standalone installer then saw no pnpm on `PATH`. Its files stay on disk because pnpm's store shares `~/.local/share/pnpm`.
- Results: `task check` and `task test:remote` pass. `task test:profiles -- ubuntu ubuntu-devstack` PASS (`ubuntu:24.04`): ubuntu unchanged and IDEMPOTENT. For ubuntu-devstack, the dry-run lists the block removal and makes no change. Bootstrap removes the block after a backup and warns about the seeded standalone binary. Verify reports `ok=79 warn=1 fail=0`, the warning being that binary. The rerun reports `changed=0`. `PNPM-FROM-DEVSTACK` passes: a login shell runs the nvm pnpm 12.9.1, and `pnpm bin -g` prints `~/.local/share/pnpm/bin`.
- State: **done**, awaiting human review
- Next action: push after confirmation, then `git pull && task devstack` on the host.

Not in any batch: a real run on `dev-01` (`task devstack` on the host, or `task bootstrap HOST=dev-01 -- --extras devstack --only base,shell,containers,k8s,devstack`). It needs separate, explicit human authorization when it happens.

## Approval and continuation

Combined approval is recorded in `spec.md` §Approval. Status: **approved** (nawodyaishan, chat, 2026-10-04).
