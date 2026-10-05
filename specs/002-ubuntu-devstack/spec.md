# Ubuntu full-stack dev stack (separate command)

## Outcome

One separate, opt-in command installs, upgrades and verifies a full-stack developer toolchain on an Ubuntu LTS host (`dev-01` and any other `ubuntu`-profile machine). Users run it alone with `task devstack` or `make devstack`. It is never part of a plain `task bootstrap`, so the existing `ubuntu` profile, its container smoke test and the lab-only hosts stay unchanged unless the stack is requested.

## Scope

In scope, all on Ubuntu LTS (24.04 and later), amd64 and arm64:

| Area | Tool | Source (from vendor docs, researched 2026-10-04) |
|---|---|---|
| Node | nvm, plus the latest LTS Node as `default` | nvm `install.sh` at a pinned tag (`v0.40.8` today), run with `PROFILE=/dev/null` so it never edits rc files; `nvm install 'lts/*'` |
| JS package managers | yarn, pnpm | Node 25+ no longer bundles Corepack, and Node 26 becomes LTS on 2026-10-28. `npm install -g corepack`, whose package ships the `yarn` and `pnpm` shims (installing the `pnpm` package too clashes on the `pnpm`/`pnpx` bins); the default versions are cached once |
| Go | latest stable Go | `go.dev/dl/?mode=json` resolves the newest stable version (`go1.27.1` today); the tarball is checksum-verified into `/usr/local/go` |
| Rust | rustup, stable toolchain, `rustfmt` + `clippy` | `sh.rustup.rs` with `-y --no-modify-path --profile default` |
| Java | Eclipse Temurin JDK (LTS 25) + Maven | Adoptium apt repo, key fingerprint-checked; `temurin-25-jdk`, apt `maven` |
| Containers | Docker CE + buildx + compose plugin | the existing `containers` module (already the profile's engine) |
| Kubernetes | kubectl, crictl, helm, k9s (existing `k8s` module) + `kind` for local clusters | existing apt repos; `kind` release binary, checksum-verified |
| Homebrew | Homebrew on Linux at `/home/linuxbrew/.linuxbrew` | official `install.sh` with `NONINTERACTIVE=1` |
| Terraform | terraform CLI | HashiCorp apt repo, key fingerprint-checked |
| AWS | AWS CLI v2 | official per-user `install.sh` (installs to `~/.local`, verifies its own download) |
| Other CLIs | gh, ripgrep, fd, fzf, bat, yq, httpie, direnv, shellcheck, sqlite3, postgresql-client, redis-tools | GitHub CLI apt repo (key-checked); the rest from Ubuntu apt |
| Build deps | build-essential, pkg-config, libssl-dev, zlib1g-dev, libffi-dev, python3-venv, python3-pip, pipx, procps, file, zip, xz-utils | Ubuntu apt |

- A new `devstack` module (`devstack_bootstrap`, `_update`, `_verify`) added to the `ubuntu` profile but gated behind a new `devstack` extra, the same mechanism as the existing `go`, `node` and `cka` extras.
- A new `--only <module,...>` engine flag that limits a run to the listed profile modules. The separate command runs exactly `base,shell,containers,k8s,devstack` with `--extras devstack`; `shell` wires `~/.bashrc` to the canonical `config/shell/bashrc` so the tools are on `PATH` on a fresh host.
- New commands: `task devstack`, `task devstack:update` and `task devstack:verify` (`-- --dry-run` passes through), each with a matching Makefile target (`devstack`, `devstack-update`, `devstack-verify`). From the Mac, `task bootstrap HOST=dev-01 -- --extras devstack --only base,shell,containers,k8s,devstack` drives the same run remotely through the existing `remote.sh`.
- `config/shell/bashrc` gains `~/.cargo/bin` on `PATH` (only if present) and `brew shellenv` (only if `/home/linuxbrew/.linuxbrew` exists). nvm is already sourced there.
- Docs: `docs/hosts.md` (Extras + a devstack section), `README.md` (profiles row, commands table, layout list).

Out of scope:

- macOS (the Brewfile already covers the Mac), RHEL and Proxmox. Proxmox stays minimal by rule. The `devstack` extra is refused on any profile other than `ubuntu`.
- Provisioning Kubernetes clusters. Per the homelab boundary this repo owns only client tools. `kind` is installed as a CLI and no cluster is ever created.
- Cloud credentials, `aws configure`, `gh auth login` and `docker login`. These stay interactive and outside Git.
- Editors and IDEs, databases as running services (only their clients), Python version managers, SDKMAN, Gradle (use the project wrapper), and language-specific global packages beyond corepack and pnpm.
- Rootless Docker or Podman on Ubuntu. Docker CE stays the engine because the profile already uses it and Compose is the common full-stack default.

## Acceptance criteria

1. `task devstack -- --dry-run` on an Ubuntu host lists every planned change and makes none.
2. `task devstack` installs everything in the scope table, and a second `task devstack` reports `changed=0`.
3. `task devstack:verify` exits 0 and reports `ok` for: `nvm`, `node` (LTS line), `npm`, `corepack`, `yarn`, `pnpm`, `go`, `rustc`, `cargo`, `java`, `javac`, `mvn`, `docker` (running when systemd is present), `kubectl`, `helm`, `k9s`, `kind`, `brew`, `terraform`, `aws`, `gh` and every listed apt package. It is read-only and makes no network calls.
4. `task devstack:update` moves Node to the newest LTS (reinstalling global packages from the previous version), Go to the newest stable, Rust via `rustup update`, the AWS CLI via its installer, `kind` to the latest release and the apt packages via `pm_upgrade`, and runs `brew update` only. It never runs a system-wide `apt upgrade`.
5. A plain `task bootstrap|verify PROFILE=ubuntu` with no extras behaves as before; devstack lines report `n/a`.
6. Every apt repo key is fingerprint-checked (HashiCorp, Adoptium, GitHub CLI), and every direct binary (Go, kind) is SHA-256 checked against the vendor's published sum. The nvm, rustup, Homebrew and AWS installers are fetched over HTTPS from their official hosts. nvm is pinned to a tag. The design records the remaining trust assumptions.
7. Bootstrap and update refuse to run as root (existing policy). Homebrew, nvm, rustup and the AWS CLI install per-user. apt and `/usr/local/go` use `sudo`.
8. No rc file is edited by a vendor installer. nvm uses `PROFILE=/dev/null`, rustup uses `--no-modify-path` and the Homebrew installer only prints instructions. Shell wiring goes through the canonical `config/shell/bashrc`.
9. `task check`, `task test:remote` and `task test:profiles ubuntu` pass. A new opt-in `task test:profiles -- ubuntu-devstack` runs dry-run → bootstrap → verify → idempotent rerun in an `ubuntu:24.04` container.
10. `bash -n`, shellcheck and the Bash 3.2 rules hold for every changed script.

## Source references

- [README.md](../../README.md) §Profiles, §Commands, §Safety model.
- [docs/hosts.md](../../docs/hosts.md) §Development VM, §Extras, §Boundary with homelab.
- [CLAUDE.md](../../CLAUDE.md): Bash 3.2, module contract, marker blocks/symlinks, homelab boundary, execution authority.
- `bootstrap/modules/lang.sh` (Go tarball and the `go`/`node` extras), `containers.sh`, `k8s.sh` (key fingerprint and checksum patterns).
- Vendor docs read through Context7 and Exa on 2026-10-04: nvm README (`PROFILE=/dev/null`, `--reinstall-packages-from`), rustup user guide (`-y --no-modify-path --profile`), Node.js release schedule and the Corepack removal in Node 25, pnpm installation (pnpm 12 native), Yarn install (`npm i -g corepack`), Adoptium Linux packages, Homebrew on Linux, the HashiCorp Terraform install page, and the AWS CLI v2 install guide.

## Edge cases

- **The LTS line moves mid-life.** Node 24 is the Active LTS today and 26 becomes LTS on 2026-10-28. `update` installs the new line with `--reinstall-packages-from=current`, then repoints `default`. Older versions are left installed.
- **The `go` extra conflicts with devstack.** With both on, the pinned `GO_VERSION` and the latest version would overwrite each other on every run. When `devstack` is on, `lang` reports `n/a` ("managed by devstack") for both `go` and `node`.
- **No systemd (containers).** Docker is installed but reported `n/a` or `warn` for "running", as today.
- **arm64.** Go, kind, the AWS CLI, Temurin, Terraform and gh all publish arm64 builds. Homebrew on Linux arm64 is a lower support tier, so a failed `brew` install there is `warn`, not `bad`.
- **Second run without network.** Bootstrap needs the network. Verify does not.
- **Root.** Refused (existing `check_root_policy`). Homebrew also refuses root.

## Open questions

None blocking. Recorded assumptions, each overridable at approval:

1. Java = Temurin 25 LTS (`JAVA_MAJOR=25` in the profile), not Ubuntu's `openjdk-*` packages.
2. "k8s" means client tooling plus `kind`, not minikube or a running cluster.
3. Recommended container engine = the existing Docker CE.
4. The `--only` flag is general-purpose (any profile, any module subset), not devstack-specific.

## Approval

Status: **approved**. Approver: nawodyaishan (chat, 2026-10-04, "approved" in reply to the draft summary). Scope covered: `spec.md`, `plan.md` and `tasks.md` as committed in `a0b4818`, including the four recorded assumptions. Authorization covers implementing Batch 1. A real run on `dev-01` or any other host is not authorized.

Amendment: pnpm through the corepack shims (no separate `pnpm` package) and the added `shell` module were accepted with Batch 1 (nawodyaishan, chat, 2026-10-05, "proceed" after the Batch 1 review summary). The scope table and command line above reflect them.
