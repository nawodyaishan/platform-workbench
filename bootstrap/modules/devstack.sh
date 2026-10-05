#!/usr/bin/env bash
# devstack: opt-in full-stack developer toolchain for the ubuntu profile (--extras devstack).
# nvm + LTS Node, yarn/pnpm via corepack, latest Go, Rust, Temurin JDK + Maven, kind,
# Homebrew, Terraform, AWS CLI v2, gh, common CLIs and the agentic-sdd agent skills. Docker and kubectl/helm/k9s come
# from the containers and k8s modules. Run alone with: task devstack. Sourced by workbench.sh.
# shellcheck disable=SC2034,SC2015

DS_NVM_DIR="$HOME/.nvm"
DS_BREW=/home/linuxbrew/.linuxbrew/bin/brew
DS_ASDD="$HOME/.local/bin/agentic-sdd"
DS_LOG="${TMPDIR:-/tmp}/platform-workbench-devstack.log"

# Signing keys, checked against each vendor's published fingerprints (2026-10-04).
# HashiCorp rotated its Linux key on 2026-09-10 (HCSEC-2026-33).
DS_KEY_HASHICORP=D55C0D1AC78A8D8126CB631CFC9CA96ACA026560
DS_KEY_ADOPTIUM=3B04D753C9050D9A5D343F39843C48A565F8F04B
DS_KEY_GITHUB_CLI="2C6106201985B60E6C7AC87323F3D4EA75716059 7F38BBB59D064DBCB3D84D725612B36462313325"

# Tools land outside the system PATH; make them visible to this run (appended, so they
# never shadow system binaries).
_ds_path() {
  local d
  for d in /usr/local/go/bin "$HOME/.cargo/bin" "$HOME/.local/bin" /home/linuxbrew/.linuxbrew/bin; do
    case ":$PATH:" in *":$d:"*) ;; *) PATH="$PATH:$d" ;; esac
  done
  export PATH
}

# _ds_nvm <command...>: run with nvm loaded and its default Node active.
_ds_nvm() {
  NVM_DIR="$DS_NVM_DIR" bash -c '. "$NVM_DIR/nvm.sh" >/dev/null 2>&1; [ "$(type -t nvm)" = function ] || exit 127; "$@"' _ "$@"
}

# _ds_fetch <url>: download an installer completely before anything runs it; prints the path.
_ds_fetch() {
  local tmp; tmp=$(mktemp)
  if curl --proto '=https' --tlsv1.2 -fsSL "$1" -o "$tmp"; then echo "$tmp"; else rm -f "$tmp"; return 1; fi
}

# _ds_latest_tag <owner/repo>: latest GitHub release tag, via the release redirect (no API quota).
_ds_latest_tag() {
  local url
  url=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$1/releases/latest") || return 1
  printf '%s\n' "${url##*/}"
}

_ds_codename() { (. /etc/os-release; echo "${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"); }

_ds_vendor_pkgs() { echo "terraform gh temurin-${JAVA_MAJOR}-jdk"; }

# --- apt: build deps, CLIs, vendor repositories ---------------------------------------------
_ds_apt() { # <bootstrap|update>
  local codename
  codename=$(_ds_codename)
  case " ${MODULES[*]-} " in *" base "*) ;; *) pm_refresh ;; esac
  if [ "$1" = update ]; then
    # shellcheck disable=SC2046
    pm_upgrade ${PKGS_DEV[@]+"${PKGS_DEV[@]}"} $(_ds_vendor_pkgs) maven
    return 0
  fi
  pm_install ${PKGS_DEV[@]+"${PKGS_DEV[@]}"}
  apt_repo_keyed hashicorp https://apt.releases.hashicorp.com/gpg "$DS_KEY_HASHICORP" \
    "deb [arch=$ARCH signed-by=/usr/share/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $codename main" || :
  apt_repo_keyed adoptium https://packages.adoptium.net/artifactory/api/gpg/key/public "$DS_KEY_ADOPTIUM" \
    "deb [arch=$ARCH signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $codename main" || :
  apt_repo_keyed github-cli https://cli.github.com/packages/githubcli-archive-keyring.gpg "$DS_KEY_GITHUB_CLI" \
    "deb [arch=$ARCH signed-by=/usr/share/keyrings/github-cli.gpg] https://cli.github.com/packages stable main" || :
  # shellcheck disable=SC2046
  pm_install $(_ds_vendor_pkgs)
  # After Temurin, so apt satisfies Maven's Java dependency with it instead of default-jdk.
  pm_install maven
}

# --- Go: latest stable ------------------------------------------------------------------------
_ds_go() { # <bootstrap|update>
  local have_ver="" latest
  [ -x /usr/local/go/bin/go ] && have_ver=$(/usr/local/go/bin/go env GOVERSION 2>/dev/null | sed 's/^go//')
  if [ "$1" = bootstrap ] && [ -n "$have_ver" ]; then ok "go $have_ver"; return 0; fi
  if is_dry_run; then dry_note "install the latest stable go (checksum-verified tarball)"; return 0; fi
  latest=$(go_latest_version) || latest=""
  [ -n "$latest" ] || { bad "could not resolve the latest go version"; return 0; }
  if [ "$have_ver" = "$latest" ]; then ok "go $latest (latest)"; else go_install_tarball "$latest"; fi
}

# --- nvm, Node LTS, corepack (yarn + pnpm) ------------------------------------------------------
_ds_nvm_install() { # installs or moves nvm to the pinned NVM_VERSION
  local cur="" f
  [ -s "$DS_NVM_DIR/nvm.sh" ] && cur=$(_ds_nvm nvm --version 2>/dev/null || true)
  if [ "v$cur" = "$NVM_VERSION" ]; then ok "nvm $cur"; return 0; fi
  if is_dry_run; then dry_note "install nvm $NVM_VERSION (no rc file edits)"; return 0; fi
  f=$(_ds_fetch "https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh") || { bad "could not download the nvm installer"; return 0; }
  mkdir -p "$DS_NVM_DIR"
  if PROFILE=/dev/null NVM_DIR="$DS_NVM_DIR" bash "$f" >>"$DS_LOG" 2>&1; then changed "installed nvm $NVM_VERSION"
  else bad "nvm install failed (log: $DS_LOG)"; fi
  rm -f "$f"
}

_ds_node() { # <bootstrap|update>
  local cur latest
  [ -s "$DS_NVM_DIR/nvm.sh" ] || { is_dry_run && dry_note "install the latest LTS node with nvm" || bad "nvm missing"; return 0; }
  cur=$(_ds_nvm nvm version default 2>/dev/null) || true
  case "$cur" in v*) ;; *) cur=N/A ;; esac
  if [ "$1" = bootstrap ] && [ "$cur" != N/A ]; then ok "node $cur (nvm default)"; return 0; fi
  if is_dry_run; then dry_note "install the latest LTS node with nvm and make it the default"; return 0; fi
  latest=$(_ds_nvm nvm version-remote --lts 2>/dev/null || true)
  case "$latest" in v*) ;; *) bad "could not resolve the latest LTS node"; return 0 ;; esac
  if [ "$cur" = "$latest" ]; then ok "node $latest (latest LTS)"; return 0; fi
  # Carry global packages (corepack) across an LTS line change.
  if [ "$cur" = N/A ]; then set -- nvm install "$latest"; else set -- nvm install --reinstall-packages-from="$cur" "$latest"; fi
  if _ds_nvm "$@" >>"$DS_LOG" 2>&1 && _ds_nvm nvm alias default "$latest" >>"$DS_LOG" 2>&1; then
    changed "node $latest is the nvm default"
  else bad "node $latest install failed (log: $DS_LOG)"; fi
}

# _ds_cp <network 0|1> <command...>: run a corepack shim from an empty directory, so a
# project's packageManager field never changes which version is fetched or reported.
_ds_cp() {
  local net=$1 dir rc=0; shift
  dir=$(mktemp -d)
  (cd "$dir" && export COREPACK_ENABLE_NETWORK="$net" COREPACK_ENABLE_DOWNLOAD_PROMPT=0 && _ds_nvm "$@") || rc=$?
  rm -rf "$dir"
  return "$rc"
}

# The corepack npm package ships the yarn and pnpm shims itself (Node 25+ no longer bundles
# it). Installing the separate pnpm package as well would clash on the pnpm/pnpx bins.
_ds_corepack() { # <bootstrap|update>
  _ds_nvm command -v node >/dev/null 2>&1 || { is_dry_run && dry_note "install corepack (yarn, pnpm)" || bad "node missing; skipped corepack"; return 0; }
  if [ "$1" = update ] || ! _ds_nvm command -v pnpm >/dev/null 2>&1 || ! _ds_nvm command -v yarn >/dev/null 2>&1; then
    if is_dry_run; then dry_note "npm install -g corepack (provides yarn and pnpm)"; return 0; fi
    if _ds_nvm npm install -g corepack@latest >>"$DS_LOG" 2>&1; then
      [ "$1" = update ] && ok "corepack $(_ds_nvm corepack --version)" || changed "installed corepack (yarn, pnpm)"
    else bad "npm install -g corepack failed (log: $DS_LOG)"; return 0; fi
  else ok "corepack yarn/pnpm shims"; fi
  is_dry_run && return 0
  # Cache the default yarn and pnpm once, so later runs (and verify) work offline.
  if _ds_cp 0 pnpm --version >/dev/null 2>&1 && _ds_cp 0 yarn --version >/dev/null 2>&1; then
    ok "yarn and pnpm cached"
  elif _ds_cp 1 pnpm --version >>"$DS_LOG" 2>&1 && _ds_cp 1 yarn --version >>"$DS_LOG" 2>&1; then
    changed "fetched default yarn and pnpm through corepack"
  else bad "corepack could not fetch yarn/pnpm (log: $DS_LOG)"; fi
}

# --- Rust -----------------------------------------------------------------------------------------
_ds_rust() { # <bootstrap|update>
  local f before after
  if [ -x "$HOME/.cargo/bin/rustup" ]; then
    if [ "$1" = bootstrap ]; then ok "$("$HOME/.cargo/bin/rustc" --version 2>/dev/null)"; return 0; fi
    if is_dry_run; then dry_note "rustup update"; return 0; fi
    before=$("$HOME/.cargo/bin/rustc" --version 2>/dev/null || true)
    "$HOME/.cargo/bin/rustup" update >>"$DS_LOG" 2>&1 || { bad "rustup update failed (log: $DS_LOG)"; return 0; }
    after=$("$HOME/.cargo/bin/rustc" --version 2>/dev/null || true)
    [ "$before" = "$after" ] && ok "$after (current)" || changed "$after"
    return 0
  fi
  if is_dry_run; then dry_note "install rustup with the stable toolchain (no rc file edits)"; return 0; fi
  f=$(_ds_fetch https://sh.rustup.rs) || { bad "could not download rustup-init"; return 0; }
  if sh "$f" -y --no-modify-path --profile default --default-toolchain stable >>"$DS_LOG" 2>&1; then changed "installed rustup + stable toolchain"
  else bad "rustup install failed (log: $DS_LOG)"; fi
  rm -f "$f"
}

# --- kind (local clusters; never creates one) ------------------------------------------------
_ds_kind() { # <bootstrap|update>
  local tag cur dir asset want got
  cur=$(kind version 2>/dev/null | awk '{print $2}' || true)
  if [ "$1" = bootstrap ] && [ -n "$cur" ]; then ok "kind $cur"; return 0; fi
  if is_dry_run; then dry_note "install the latest kind (checksum-verified)"; return 0; fi
  tag=$(_ds_latest_tag kubernetes-sigs/kind) || tag=""
  [ -n "$tag" ] || { bad "could not resolve the latest kind release"; return 0; }
  if [ "$cur" = "$tag" ]; then ok "kind $tag (latest)"; return 0; fi
  dir=$(mktemp -d); asset="kind-linux-$ARCH"
  if ! curl -fsSL "https://github.com/kubernetes-sigs/kind/releases/download/$tag/$asset" -o "$dir/$asset" \
      || ! curl -fsSL "https://github.com/kubernetes-sigs/kind/releases/download/$tag/$asset.sha256sum" -o "$dir/sum"; then
    rm -rf "$dir"; bad "could not download kind $tag and its checksum"; return 0
  fi
  want=$(awk '{print $1; exit}' "$dir/sum"); got=$(sha256_file "$dir/$asset")
  if [ -n "$want" ] && [ "$want" = "$got" ] && $SUDO install -m 0755 "$dir/$asset" /usr/local/bin/kind; then changed "installed kind $tag"
  else bad "kind $tag checksum mismatch or install failed"; fi
  rm -rf "$dir"
}

# --- AWS CLI v2 (per user, ~/.local) -----------------------------------------------------------
_ds_aws() { # <bootstrap|update>
  local f before after
  before=$("$HOME/.local/bin/aws" --version 2>/dev/null | awk '{print $1}' || true)
  if [ "$1" = bootstrap ] && [ -n "$before" ]; then ok "$before"; return 0; fi
  if is_dry_run; then dry_note "install or update AWS CLI v2 for $USER (signature-checked by the installer)"; return 0; fi
  f=$(_ds_fetch https://awscli.amazonaws.com/v2/install.sh) || { bad "could not download the AWS CLI installer"; return 0; }
  if bash "$f" --quiet >>"$DS_LOG" 2>&1; then
    after=$("$HOME/.local/bin/aws" --version 2>/dev/null | awk '{print $1}' || true)
    [ "$before" = "$after" ] && ok "$after (current)" || changed "installed $after"
  else bad "AWS CLI install failed (log: $DS_LOG)"; fi
  rm -f "$f"
}

# --- Homebrew on Linux --------------------------------------------------------------------------
_ds_brew() { # <bootstrap|update>
  local f out
  # arm64 Linux is a lower Homebrew support tier, so failures there only warn.
  local miss=bad; [ "$ARCH" = arm64 ] && miss=warn
  if [ -x "$DS_BREW" ]; then
    if [ "$1" = bootstrap ]; then ok "$("$DS_BREW" --version 2>/dev/null | head -1)"; return 0; fi
    if is_dry_run; then dry_note "brew update (no formula upgrades)"; return 0; fi
    out=$("$DS_BREW" update 2>&1) || { warn "brew update failed"; return 0; }
    case "$out" in *"Already up-to-date"*) ok "Homebrew current" ;; *) changed "brew update" ;; esac
    return 0
  fi
  if is_dry_run; then dry_note "install Homebrew to /home/linuxbrew/.linuxbrew"; return 0; fi
  f=$(_ds_fetch https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh) || { $miss "could not download the Homebrew installer"; return 0; }
  if NONINTERACTIVE=1 bash "$f" >>"$DS_LOG" 2>&1; then changed "installed Homebrew"
  else $miss "Homebrew install failed (log: $DS_LOG)"; fi
  rm -f "$f"
}

# --- agentic-sdd skills (Claude Code, Codex, Antigravity CLI) --------------------------------
# The release ships only a macOS binary and the Go module path is not go-installable, so
# build the pinned tag from source with the Go installed above. The binary embeds the
# skills; its apply backs up anything it replaces and touches only agentic-sdd-* skills.
_ds_asdd_version() { "$DS_ASDD" version 2>/dev/null | awk 'NR==1 {print $2}'; }

# _ds_asdd_plan: preview counts as "<install> <replace>" (read-only, offline).
_ds_asdd_plan() {
  "$DS_ASDD" preview | awk '/^install /{i++} /^replace /{r++} END{printf "%d %d\n", i, r}'
}

_ds_asdd_build() {
  local dir want=${AGENTIC_SDD_VERSION#v}
  if [ "$(_ds_asdd_version)" = "$want" ]; then ok "agentic-sdd $want"; return 0; fi
  if is_dry_run; then dry_note "build agentic-sdd $AGENTIC_SDD_VERSION from source into ~/.local/bin"; return 0; fi
  [ -x /usr/local/go/bin/go ] || { bad "go missing; skipped agentic-sdd"; return 1; }
  dir=$(mktemp -d)
  if ! git -c advice.detachedHead=false clone -q --depth 1 --branch "$AGENTIC_SDD_VERSION" \
      https://github.com/nawodyaishan/agentic-sdd.git "$dir/src" >>"$DS_LOG" 2>&1; then
    rm -rf "$dir"; bad "could not clone agentic-sdd $AGENTIC_SDD_VERSION"; return 1
  fi
  # A moved tag fails closed, like a rotated apt key.
  if [ "$(git -C "$dir/src" rev-parse HEAD)" != "$AGENTIC_SDD_COMMIT" ]; then
    rm -rf "$dir"; bad "agentic-sdd $AGENTIC_SDD_VERSION is not the pinned commit $AGENTIC_SDD_COMMIT"; return 1
  fi
  mkdir -p "$(dirname "$DS_ASDD")"
  if (cd "$dir/src" && GOTOOLCHAIN=local CGO_ENABLED=0 /usr/local/go/bin/go build -trimpath \
      -ldflags "-s -w -X agentic-sdd/internal/version.Version=$want -X agentic-sdd/internal/version.Commit=${AGENTIC_SDD_COMMIT:0:7}" \
      -o "$DS_ASDD" ./cmd/agentic-sdd) >>"$DS_LOG" 2>&1; then
    changed "built agentic-sdd $want"
  else bad "agentic-sdd build failed (log: $DS_LOG)"; rm -rf "$dir"; return 1; fi
  rm -rf "$dir"
}

_ds_asdd() {
  local plan
  _ds_asdd_build || return 0
  # Only reached in a dry-run that would (re)build: preview the pinned binary, not an old one.
  if [ "$(_ds_asdd_version)" != "${AGENTIC_SDD_VERSION#v}" ]; then
    dry_note "apply the agentic-sdd skills to ~/.claude, ~/.codex, ~/.agents and ~/.gemini (backing up any replaced)"; return 0
  fi
  plan=$(_ds_asdd_plan) || { bad "agentic-sdd preview failed"; return 0; }
  if [ "$plan" = "0 0" ]; then ok "agentic-sdd skills up to date"; return 0; fi
  if is_dry_run; then dry_note "apply agentic-sdd skills (install/replace: ${plan% *}/${plan#* }; replaced ones are backed up)"; return 0; fi
  if "$DS_ASDD" apply >>"$DS_LOG" 2>&1; then changed "applied agentic-sdd skills (backups in ~/.agentic-sdd/backups)"
  else bad "agentic-sdd apply failed (log: $DS_LOG)"; fi
}

_ds_run() { # <bootstrap|update>
  _ds_path
  require_sudo
  _ds_apt "$1"
  _ds_go "$1"
  _ds_nvm_install
  _ds_node "$1"
  _ds_corepack "$1"
  _ds_rust "$1"
  _ds_kind "$1"
  _ds_aws "$1"
  _ds_brew "$1"
  _ds_asdd
}

devstack_bootstrap() {
  hdr "devstack"
  extra_on devstack || { na "devstack extra not requested"; return 0; }
  _ds_run bootstrap
  is_dry_run || info "new shells pick up nvm, cargo and brew from config/shell/bashrc"
}

devstack_update() {
  hdr "devstack (update)"
  extra_on devstack || { na "devstack extra not requested"; return 0; }
  _ds_run update
}

# _ds_check <label> <command...>: ok with the first output line, bad when it fails.
_ds_check() {
  local label=$1 out; shift
  if out=$("$@" 2>&1 | head -1) && [ -n "$out" ]; then ok "$label: $out"; else bad "$label missing"; fi
}

devstack_verify() {
  hdr "devstack (verify)"
  extra_on devstack || { na "devstack extra not requested"; return 0; }
  _ds_path
  # shellcheck disable=SC2046
  pm_check ${PKGS_DEV[@]+"${PKGS_DEV[@]}"} $(_ds_vendor_pkgs) maven
  _ds_check go /usr/local/go/bin/go version
  _ds_check nvm _ds_nvm nvm --version
  local lts
  lts=$(_ds_nvm node -p 'process.release.lts || ""' 2>/dev/null || true)
  if [ -n "$lts" ]; then ok "node $(_ds_nvm node --version) (LTS $lts)"; else bad "nvm default node missing or not an LTS release"; fi
  _ds_check npm _ds_nvm npm --version
  _ds_check corepack _ds_nvm corepack --version
  _ds_check yarn _ds_cp 0 yarn --version
  _ds_check pnpm _ds_cp 0 pnpm --version
  _ds_check rustc "$HOME/.cargo/bin/rustc" --version
  _ds_check cargo "$HOME/.cargo/bin/cargo" --version
  _ds_check clippy "$HOME/.cargo/bin/cargo" clippy --version
  _ds_check java java -version
  _ds_check javac javac -version
  _ds_check mvn mvn -v
  _ds_check terraform terraform version
  _ds_check aws "$HOME/.local/bin/aws" --version
  _ds_check gh gh --version
  _ds_check kind kind version
  if [ -x "$DS_BREW" ]; then ok "$("$DS_BREW" --version 2>/dev/null | head -1)"
  elif [ "$ARCH" = arm64 ]; then warn "Homebrew missing (arm64 Linux is a lower support tier)"
  else bad "Homebrew missing"; fi
  local v plan
  v=$(_ds_asdd_version)
  if [ "$v" = "${AGENTIC_SDD_VERSION#v}" ]; then ok "agentic-sdd $v"
  elif [ -n "$v" ]; then bad "agentic-sdd $v, expected ${AGENTIC_SDD_VERSION#v}"
  else bad "agentic-sdd missing"; return 0; fi
  plan=$(_ds_asdd_plan 2>/dev/null) || plan="? ?"
  case "$plan" in
    "0 0") ok "agentic-sdd skills up to date" ;;
    "0 "*) warn "agentic-sdd skills edited locally (${plan#* } differ; task devstack restores them, with a backup)" ;;
    *) bad "agentic-sdd skills missing or unreadable (preview: $plan)" ;;
  esac
}
