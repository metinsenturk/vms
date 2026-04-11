#!/usr/bin/env bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

log() {
  printf "[install-docker] %s\n" "$1"
}

remove_conflicting_packages() {
  local packages
  packages=(
    docker.io
    docker-compose
    docker-compose-v2
    docker-doc
    podman-docker
    containerd
    runc
  )

  local to_remove
  to_remove=()

  for pkg in "${packages[@]}"; do
    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
      to_remove+=("$pkg")
    fi
  done

  if [[ ${#to_remove[@]} -gt 0 ]]; then
    log "Removing conflicting packages: ${to_remove[*]}"
    sudo apt-get remove -y "${to_remove[@]}"
  else
    log "No conflicting Docker packages found"
  fi
}

configure_docker_repo() {
  local codename
  local arch

  # shellcheck disable=SC1091
  source /etc/os-release
  codename="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
  arch="$(dpkg --print-architecture)"

  sudo install -m 0755 -d /etc/apt/keyrings
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc

  sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${codename}
Components: stable
Architectures: ${arch}
Signed-By: /etc/apt/keyrings/docker.asc
EOF
}

install_packages() {
  log "Installing Docker Engine, Compose plugin, and base tools"
  sudo apt-get update
  sudo apt-get install -y \
    ca-certificates \
    curl \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin \
    git \
    make \
    yq
}

configure_user_access() {
  local target_user
  target_user="$(id -un)"

  if id -nG "$target_user" | grep -qw docker; then
    log "User '$target_user' is already in docker group"
    return
  fi

  log "Adding user '$target_user' to docker group"
  sudo usermod -aG docker "$target_user"
}

verify_installation() {
  log "Enabling and starting Docker service"
  sudo systemctl enable --now docker

  log "Verifying Docker installation"
  sudo docker --version
  sudo docker compose version

  log "Done. Re-login or run 'newgrp docker' for group changes to take effect."
}

main() {
  log "Updating apt metadata"
  sudo apt-get update

  remove_conflicting_packages

  log "Installing apt prerequisites"
  sudo apt-get install -y ca-certificates curl

  configure_docker_repo
  install_packages
  configure_user_access
  verify_installation
}

main
