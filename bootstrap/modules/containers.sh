#!/usr/bin/env bash
# containers: podman (rhel) or Docker CE (ubuntu) per CONTAINER_ENGINE. Sourced by workbench.sh.
# shellcheck disable=SC2034,SC2015

_docker_repo() {
  case "$OS_FAMILY" in
    dnf)
      $SUDO dnf install -y -q dnf-plugins-core >/dev/null 2>&1
      $SUDO dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >/dev/null 2>&1 \
        || $SUDO dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/centos/docker-ce.repo >/dev/null 2>&1
      ;;
    apt)
      local codename
      # shellcheck disable=SC1091
      codename=$(. /etc/os-release; echo "${VERSION_CODENAME:-}")
      $SUDO install -d -m 0755 /etc/apt/keyrings
      curl -fsSL "https://download.docker.com/linux/$OS_ID/gpg" | $SUDO tee /etc/apt/keyrings/docker.asc >/dev/null
      printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/%s %s stable\n' "$ARCH" "$OS_ID" "$codename" \
        | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null
      $SUDO apt-get update -qq >/dev/null 2>&1
      ;;
  esac
}

_engine_pkgs() {
  case "${CONTAINER_ENGINE:-none}" in
    podman) echo "podman buildah skopeo" ;;
    docker) echo "docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin" ;;
    *) echo "" ;;
  esac
}

containers_bootstrap() {
  hdr "containers (${CONTAINER_ENGINE:-none})"
  case "${CONTAINER_ENGINE:-none}" in
    none) na "no container engine for this profile"; return 0 ;;
    orbstack) [ -d /Applications/OrbStack.app ] && ok "OrbStack present" || warn "OrbStack not installed"; return 0 ;;
  esac
  require_sudo
  if [ "$CONTAINER_ENGINE" = docker ] && ! have docker; then
    if is_dry_run; then dry_note "add Docker CE repo"; else _docker_repo || warn "adding Docker repo reported errors"; fi
  fi
  # shellcheck disable=SC2046
  pm_install $(_engine_pkgs)
  if [ "$CONTAINER_ENGINE" = docker ] && ! is_dry_run && have_systemd; then
    $SUDO systemctl enable --now docker >/dev/null 2>&1 || warn "could not enable docker"
    if ! id -nG | tr ' ' '\n' | grep -Fxq docker; then
      $SUDO usermod -aG docker "$USER" && changed "added $USER to docker group (log out/in to apply)"
    fi
  fi
}

containers_update() {
  hdr "containers (update)"
  [ "${CONTAINER_ENGINE:-none}" = none ] && { na "no engine"; return 0; }
  case "$CONTAINER_ENGINE" in orbstack) na "OrbStack updates itself"; return 0 ;; esac
  require_sudo
  # shellcheck disable=SC2046
  pm_upgrade $(_engine_pkgs)
}

containers_verify() {
  hdr "containers (verify)"
  case "${CONTAINER_ENGINE:-none}" in
    none) na "no container engine for this profile" ;;
    orbstack) [ -d /Applications/OrbStack.app ] && ok "OrbStack present" || warn "OrbStack not installed" ;;
    podman) if have podman; then ok "podman $(podman --version | awk '{print $3}')"; else bad "podman missing"; fi ;;
    docker)
      if have docker; then ok "docker client"; else bad "docker missing"; return 0; fi
      if have_systemd; then systemctl is-active --quiet docker && ok "docker running" || bad "docker not running"; fi
      ;;
  esac
}
