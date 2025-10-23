#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  SUDO=sudo
else
  SUDO=
fi

DOCKERHUB_USERNAME=${DOCKERHUB_USERNAME:-}
DOCKERHUB_TOKEN=${DOCKERHUB_TOKEN:-}

if [[ -z "$DOCKERHUB_USERNAME" || -z "$DOCKERHUB_TOKEN" ]]; then
  echo "Error: DOCKERHUB_USERNAME and DOCKERHUB_TOKEN environment variables must be set." >&2
  exit 1
fi

echo "Updating apt package index..."
$SUDO apt-get update -y

$SUDO apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

if [[ ! -f /etc/apt/keyrings/docker.gpg ]]; then
  echo "Adding Docker's official GPG key..."
  $SUDO install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  $SUDO chmod a+r /etc/apt/keyrings/docker.gpg
fi

echo "Setting up Docker repository..."
release=$(lsb_release -cs)
cat <<REPO | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $release stable
REPO

$SUDO apt-get update -y

echo "Installing Docker Engine and plugins..."
$SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

if ! systemctl is-active --quiet docker; then
  echo "Starting Docker service..."
  $SUDO systemctl enable --now docker
fi

echo "Docker version:"
docker --version
echo "Docker Compose version:"
docker compose version

if [[ -n "$SUDO" ]]; then
  echo "Adding user ${SUDO_USER:-$USER} to docker group..."
  $SUDO usermod -aG docker ${SUDO_USER:-$USER}
fi

echo "Logging in to Docker Hub..."
if [[ -n "$SUDO" ]]; then
  printf '%s' "$DOCKERHUB_TOKEN" | $SUDO docker login --username "$DOCKERHUB_USERNAME" --password-stdin
else
  printf '%s' "$DOCKERHUB_TOKEN" | docker login --username "$DOCKERHUB_USERNAME" --password-stdin
fi

echo "Docker setup complete. You may need to log out and back in for group changes to take effect."