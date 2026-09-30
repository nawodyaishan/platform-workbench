#!/usr/bin/env bash
# k8s: kubectl + cri-tools from pkgs.k8s.io (Linux, when K8S_MINOR is set).
# shellcheck disable=SC2034,SC2015

_k8s_pkgs() { echo "kubectl cri-tools"; }

_helm_repo_ubuntu() {
  local key; key=$(mktemp)
  if ! curl -fsSL 'https://packages.buildkite.com/helm-linux/helm-debian/gpgkey' -o "$key"; then
    rm -f "$key"; bad "could not download Helm apt key"; return 1
  fi
  local fingerprint
  fingerprint=$(gpg --show-keys --with-colons "$key" 2>/dev/null | awk -F: '$1=="fpr" {print $10; exit}')
  if [ "$fingerprint" != DDF78C3E6EBB2D2CC223C95C62BA89D07698DBC6 ]; then
    rm -f "$key"; bad "unexpected Helm apt key fingerprint"; return 1
  fi
  gpg --dearmor < "$key" | $SUDO tee /usr/share/keyrings/helm.gpg >/dev/null
  rm -f "$key"
  printf '%s\n' 'deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main' \
    | $SUDO tee /etc/apt/sources.list.d/helm-stable-debian.list >/dev/null
  $SUDO apt-get update -qq >/dev/null
  changed "configured Helm apt repository"
}

_k9s_ubuntu() { # bootstrap or update; checks the release checksum before installing.
  local dir asset expected actual installed candidate
  dir=$(mktemp -d)
  asset="k9s_linux_${ARCH}.deb"
  if ! curl -fsSL "https://github.com/derailed/k9s/releases/latest/download/$asset" -o "$dir/$asset" \
      || ! curl -fsSL 'https://github.com/derailed/k9s/releases/latest/download/checksums.sha256' -o "$dir/checksums.sha256"; then
    rm -rf "$dir"; bad "could not download k9s release and checksum"; return 0
  fi
  expected=$(awk -v name="$asset" '$2==name || $2=="*"name {print $1; exit}' "$dir/checksums.sha256")
  actual=$(sha256sum "$dir/$asset" | cut -d' ' -f1)
  if [ -z "$expected" ] || [ "$actual" != "$expected" ]; then
    rm -rf "$dir"; bad "k9s release checksum mismatch"; return 0
  fi
  candidate=$(dpkg-deb -f "$dir/$asset" Version)
  installed=$(dpkg-query -W -f='${Version}' k9s 2>/dev/null || true)
  if [ "$candidate" = "$installed" ]; then ok "k9s $installed current"
  elif $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$dir/$asset" >/dev/null; then changed "installed k9s $candidate"
  else bad "could not install k9s $candidate"; fi
  rm -rf "$dir"
}

_k8s_repo() {
  case "$OS_FAMILY" in
    dnf)
      printf '[kubernetes]\nname=Kubernetes\nbaseurl=https://pkgs.k8s.io/core:/stable:/v%s/rpm/\nenabled=1\ngpgcheck=1\ngpgkey=https://pkgs.k8s.io/core:/stable:/v%s/rpm/repodata/repomd.xml.key\n' "$K8S_MINOR" "$K8S_MINOR" \
        | $SUDO tee /etc/yum.repos.d/kubernetes.repo >/dev/null ;;
    apt)
      $SUDO install -d -m 0755 /etc/apt/keyrings
      curl -fsSL "https://pkgs.k8s.io/core:/stable:/v$K8S_MINOR/deb/Release.key" | $SUDO gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
      printf 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v%s/deb/ /\n' "$K8S_MINOR" \
        | $SUDO tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
      $SUDO apt-get update -qq >/dev/null 2>&1 ;;
  esac
}

k8s_bootstrap() {
  hdr "kubernetes tooling"
  if [ "$WB_OS" = macos ]; then ok "kubectl/helm/k9s/kubectx/stern/kind come from the Brewfile"; return 0; fi
  [ -n "${K8S_MINOR:-}" ] || { na "no K8S_MINOR for this profile"; return 0; }
  require_sudo
  if is_dry_run; then dry_note "add pkgs.k8s.io v$K8S_MINOR repo; install $(_k8s_pkgs)"; else
    have kubectl || { _k8s_repo || warn "adding the Kubernetes repo reported errors"; }
    # shellcheck disable=SC2046
    pm_install $(_k8s_pkgs)
  fi
  if [ "$WB_PROFILE" = ubuntu ]; then
    if is_dry_run; then dry_note "configure fingerprint-checked Helm apt repo; install helm and checksum-checked k9s"
    else
      if [ ! -f /etc/apt/sources.list.d/helm-stable-debian.list ] || [ ! -f /usr/share/keyrings/helm.gpg ]; then _helm_repo_ubuntu || return 0; fi
      pm_install helm
      if have k9s; then ok "k9s present"; else _k9s_ubuntu; fi
    fi
  fi
}

k8s_update() {
  hdr "kubernetes tooling (update)"
  if [ "$WB_OS" = macos ]; then na "handled by the base module (Brewfile)"; return 0; fi
  [ -n "${K8S_MINOR:-}" ] || { na "no K8S_MINOR"; return 0; }
  require_sudo
  # shellcheck disable=SC2046
  pm_upgrade $(_k8s_pkgs)
  if [ "$WB_PROFILE" = ubuntu ]; then
    if is_dry_run; then dry_note "upgrade helm and k9s"
    else pm_upgrade helm; _k9s_ubuntu; fi
  fi
}

k8s_verify() {
  hdr "kubernetes tooling (verify)"
  if [ "$WB_OS" = macos ]; then
    local t; for t in kubectl helm k9s kubectx stern kind; do if have "$t"; then ok "$t"; else bad "$t missing"; fi; done
    return 0
  fi
  [ -n "${K8S_MINOR:-}" ] || { na "no K8S_MINOR for this profile"; return 0; }
  if have kubectl; then
    local version; version=$(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion' 2>/dev/null)
    case "$version" in v"$K8S_MINOR".*) ok "kubectl $version" ;; *) bad "kubectl $version differs from v$K8S_MINOR" ;; esac
  else bad "kubectl missing"; fi
  if have crictl; then ok "crictl"; else bad "crictl missing"; fi
  if [ "$WB_PROFILE" = ubuntu ]; then
    have helm && ok "helm" || bad "helm missing"
    have k9s && ok "k9s" || bad "k9s missing"
  fi
}
