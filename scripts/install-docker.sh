#!/bin/bash
# One-time host setup. Requires sudo.
# Run as: sudo bash scripts/install-docker.sh

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "Re-running with sudo ..."
    exec sudo bash "$0" "$@"
fi

TARGET_USER="${SUDO_USER:-hashbox699}"

echo ">>> Installing Docker engine + git/make ..."
apt-get update
apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg lsb-release \
    docker.io docker-buildx \
    git make rsync

systemctl enable --now docker

echo ">>> Adding ${TARGET_USER} to docker group ..."
usermod -aG docker "${TARGET_USER}"

echo ">>> Done."
echo "  ${TARGET_USER} must log out and back in (or run 'newgrp docker') for group to take effect."
docker --version
