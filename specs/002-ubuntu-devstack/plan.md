# Plan: Ubuntu full-stack dev stack

Spec revision used: `spec.md` as drafted 2026-10-04.

## Approach

Add one module, `bootstrap/modules/devstack.sh`, to the `ubuntu` profile behind a `devstack` extra. Reuse the existing modules for the parts the profile already owns: `containers` for Docker CE and `k8s` for kubectl, crictl, helm and k9s. Add a general `--only` filter to the engine so the separate command runs just `base,shell,containers,k8s,devstack`. Task and Make get thin entries that call the engine. There is no new install path that the engine and `remote.sh` don't already understand.

### Command surface

```text
task devstack            [-- --dry-run]   -> workbench.sh bootstrap --profile ubuntu --extras devstack --only base,shell,containers,k8s,devstack
task devstack:update     [-- --dry-run]   -> same with update
task devstack:verify                      -> same with verify
make devstack | devstack-update | devstack-verify  [ARGS=--dry-run]
```

All three force `PROFILE=ubuntu`. The engine's existing `check_profile_host` and `check_root_policy` refuse a non-Ubuntu host or root. Remote use from the Mac needs no new code: `remote.sh` already forwards `--extras` and any safe argument.

### Engine change: `--only`

`workbench.sh` takes `--only a,b,c`. After the profile is sourced, `MODULES` is filtered to the listed names, keeping profile order. An unknown name, or a name that isn't in the profile, is a usage error rather than a silent skip, so a typo can't turn into "nothing ran". Bash 3.2 safe: a comma `case` match, no arrays beyond the existing `MODULES`.

### Module layout (`devstack.sh`)

Each tool gets one small `_ds_<tool>` function for install and upgrade and one `_ds_<tool>_verify` function. `devstack_bootstrap`, `_update` and `_verify` call them in a fixed order:

1. **apt packages**: build deps and CLIs via `pm_install` / `pm_upgrade` / `pm_check`. Ubuntu names `fd-find` and `bat` as `fdfind`/`batcat`, and verify checks those names. No symlinks are created; aliases are left to the user.
2. **Vendor apt repos**: HashiCorp, Adoptium and GitHub CLI. A shared `apt_repo_keyed <name> <key-url> <fingerprints> <deb-line>` helper in `bootstrap/lib/install.sh` follows `_helm_repo_ubuntu`: download the key, require every primary key in it to be one of the pinned fingerprints, dearmor it (or copy a binary keyring) into `/usr/share/keyrings/<name>.gpg`, write `/etc/apt/sources.list.d/<name>.list`, and touch nothing when both files already exist. Then `pm_install terraform temurin-${JAVA_MAJOR}-jdk gh`. Pinned fingerprints, each confirmed against the vendor page at implementation time:
   - HashiCorp `D55C0D1AC78A8D8126CB631CFC9CA96ACA026560` (rotated on 2026-09-10 per HCSEC-2026-33; the earlier `798AEC65…` key is retired)
   - Adoptium `3B04D753C9050D9A5D343F39843C48A565F8F04B`
   - GitHub CLI `2C6106201985B60E6C7AC87323F3D4EA75716059` and `7F38BBB59D064DBCB3D84D725612B36462313325` (the published keyring holds both; the first has expired)
3. **Go (latest)**: resolve the newest stable version from `go.dev/dl/?mode=json`. If `/usr/local/go` already reports that version, it's `ok`. Otherwise install with the same checksum-verified tarball code as `lang`. `_go_install` moves out of `lang.sh` into a new `bootstrap/lib/install.sh` as `go_install_tarball <version>`, so both modules share one implementation. `lang.sh` keeps its pinned `GO_VERSION` behavior.
4. **nvm + Node LTS**: if `~/.nvm/nvm.sh` is missing, run `PROFILE=/dev/null bash` on `raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh`. On bootstrap, `nvm install 'lts/*'` only when no LTS is installed. On update, `nvm install --reinstall-packages-from=<old default> <latest>` when `nvm version-remote --lts` differs from the installed default. Then `nvm alias default <latest>` (an exact version, so `nvm version default` is a stable idempotency check). nvm functions run inside `bash -c '. "$NVM_DIR/nvm.sh"; …'` because nvm needs to be sourced and its scripts aren't `set -u` clean.
5. **corepack, yarn, pnpm**: `npm install -g corepack` (skipped when the shims exist on bootstrap, run on update). The corepack npm package ships the `yarn` and `pnpm` shims itself, so no `corepack enable` is needed. The separate `pnpm` npm package is not installed: its `pnpm`/`pnpx` bins clash with corepack's. Bootstrap then fetches the default yarn and pnpm once from an empty directory, so verify can run them with `COREPACK_ENABLE_NETWORK=0`. Everything lives in the nvm Node prefix and moves with `--reinstall-packages-from`.
6. **Rust**: if `~/.cargo/bin/rustup` is missing, run `sh.rustup.rs` with `-y --no-modify-path --profile default --default-toolchain stable`. On update, `rustup update`.
7. **kind**: GitHub `releases/latest`, download `kind-linux-$ARCH` plus its `.sha256sum`, verify, and `install -m 0755` to `/usr/local/bin/kind`. It's `ok` when the installed `kind version` matches the latest tag.
8. **AWS CLI v2**: if `aws` is missing (or on update), run `awscli.amazonaws.com/v2/install.sh | bash` (per-user `~/.local/share/aws-cli` plus a symlink in `~/.local/bin`, which bashrc already puts on `PATH`).
9. **Homebrew**: if `/home/linuxbrew/.linuxbrew/bin/brew` is missing, run `NONINTERACTIVE=1 bash` on the official `install.sh`. It needs `build-essential procps curl file git` from step 1 and passwordless `sudo` only to create `/home/linuxbrew`. `require_sudo` primes the sudo timestamp first. On update, `brew update` only. devstack installs no formulae with brew, so `pm_upgrade` scope is not widened.

Bootstrap order puts apt (1–2) before everything that needs `curl`, `gpg`, compilers or `git`. Verify only reads: `have`, `--version` and `dpkg -s`, with no network calls, so it stays fast and offline-safe.

### Profile and extras wiring

- `profiles/ubuntu.sh`: `MODULES` gains `devstack` at the end. New variables: `NVM_VERSION=v0.40.8`, `JAVA_MAJOR=25`, `PKGS_DEV=(…)`.
- `workbench.sh`: defaults `PKGS_DEV=()`, `NVM_VERSION=""`, `JAVA_MAJOR=""`. It dies if `extra_on devstack` and the profile isn't `ubuntu`.
- `devstack_*`: `na "devstack extra not requested"` unless `extra_on devstack`.
- `lang.sh`: with `extra_on devstack`, Go and Node each report `n/a (managed by devstack)` instead of installing, which avoids the version fight described in spec §Edge cases.

### Shell wiring

`config/shell/bashrc`: add `"$HOME/.cargo/bin"` to the existing only-if-present PATH loop, and add `[ -x /home/linuxbrew/.linuxbrew/bin/brew ] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"`, which is the Homebrew-documented line. `zshrc` is untouched because it is the macOS shell here. No marker-block change: the existing single block already sources `bashrc`.

## Affected components

- New: `bootstrap/modules/devstack.sh`, `bootstrap/lib/install.sh`.
- Changed: `bootstrap/workbench.sh` (`--only`, devstack guard, new defaults, source `lib/install.sh`), `bootstrap/modules/lang.sh` (shared Go installer, devstack deferral), `bootstrap/profiles/ubuntu.sh`, `config/shell/bashrc`, `Taskfile.yml` (three tasks, help text, `lint` script list already globbed), `Makefile` (three targets plus `.PHONY`), `scripts/test-profiles.sh` (opt-in `ubuntu-devstack` case), `scripts/test-remote.sh` (an `--only` argument passes the safety filter), `docs/hosts.md`, `README.md`.
- Unchanged: macOS, RHEL and Proxmox profiles, the Brewfile, `containers.sh`, `k8s.sh`, and `remote.sh`.

## Design decisions

1. **Extra plus `--only` rather than a new profile.** A new `ubuntu-dev` profile would need host detection, `hosts.conf` and test changes, and would duplicate the module list. An extra keeps one Ubuntu profile, and `--only` makes "separate command" literal: the dev stack runs without re-running shell, git, ssh, tailscale or cka.
2. **Reuse `containers` and `k8s`** instead of re-implementing Docker and kubectl, which keeps one canonical implementation per tool.
3. **Temurin over Ubuntu `openjdk-*`**: it covers every LTS on every Ubuntu LTS and has a single vendor repo with a fingerprint check. SDKMAN was rejected because it is a second version manager that edits rc files.
4. **corepack from npm in the nvm prefix, providing both pnpm and yarn**, not the standalone `get.pnpm.io` script, so the JS toolchain has one owner (nvm) and upgrades together.
5. **Latest, not pinned, for Go, Node LTS, Rust, kind and the AWS CLI** because the user asked for latest. Installer tooling is pinned where the vendor offers tags (nvm). Homebrew, rustup and AWS installers have no stable tag and are taken from `HEAD`/`latest` over HTTPS, which is the stated trust assumption.
6. **`update` stays scoped**: named apt packages through `pm_upgrade`, plus each tool's own updater. Never `apt upgrade` or `brew upgrade`.

## Risks

- **Remote-script trust (nvm, rustup, Homebrew, AWS).** These execute vendor code fetched at run time. Mitigations: HTTPS only (`--proto '=https' --tlsv1.2` where the vendor documents it), the nvm tag is pinned, the scripts are never run as root, and `--dry-run` shows each one before it runs. The AWS script verifies its own zip.
- **Corepack is experimental and unbundled.** It provides both yarn and pnpm. If it breaks, verify flags missing `yarn`/`pnpm` as `bad`; the fallback is `npm i -g pnpm` without corepack.
- **The Node LTS switch on 2026-10-28.** An `update` after that date moves `default` to 26. That's intended and documented.
- **Homebrew prefix on arm64** is lower-tier support, so a failure there is `warn`.
- **The container test is heavy** (Rust, Homebrew and Node downloads, roughly 10 minutes). That's why `ubuntu-devstack` is opt-in and not part of the default `test:profiles` list. Its `limited 900` timeout may need raising to 1800.
- **Fingerprint drift.** If a vendor rotates a key, bootstrap fails closed with `bad`, which is the same behavior as Helm today.

## Specialists and tools

- No additional specialist skill is needed. This is Bash and apt work in the existing module pattern. `docker-expert` was considered and not needed, because Docker reuses the existing module.
- Tools: CodeGraph and local reads for code; Context7 (nvm, rustup) and Exa (Node schedule, pnpm, Yarn, Adoptium, Homebrew, Terraform, AWS CLI) for vendor docs, already consulted. At implementation time, re-check the three key fingerprints and the nvm tag against the vendor pages.
- Docker (OrbStack) on the Mac for `task test:profiles -- ubuntu ubuntu-devstack`. That is local container testing, which counts as development.
- **Execution authority:** a real `task devstack` on `dev-01` (or `task bootstrap HOST=dev-01 …`) acts on a real machine and needs separate, explicit authorization at that time. Approving these documents does not grant it.

## Checks

- `task check` (bash -n, shellcheck, secrets, repo/link checks).
- `task test:remote`, which must still pass, with a new case for the `--only` argument.
- `task test:profiles -- ubuntu`, which must be unchanged (devstack reports `n/a`).
- `task test:profiles -- ubuntu-devstack`: dry-run → bootstrap → verify → rerun `changed=0`.
- `bootstrap/workbench.sh bootstrap --profile ubuntu --extras devstack --only base,devstack --dry-run --force-profile` on the Mac only exercises argument parsing up to the OS check. Real coverage is the container.

Next document: `tasks.md`.
