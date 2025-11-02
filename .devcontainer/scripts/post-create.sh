#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_DIR="${DEVCONTAINER_PROJECT_ROOT:-$(pwd)}"
cd "$WORKSPACE_DIR"

# Git config and credential manager
echo "Configuring gh cli"
git config --global user.email "mathias@vkaiz.de"
git config --global user.name "mvk"
gh auth login

echo "Logging into docker registry"
docker login

# Install requirements
if [ -f requirements.txt ]; then
  echo "Installing requirements.txt"
  pip install --no-cache-dir -r requirements.txt
fi

if [ -f requirements-dev.txt ]; then
  echo "Installing requirements-dev.txt"
  pip install --no-cache-dir -r requirements-dev.txt
fi

if [ -f backend/requirements.txt ]; then
  echo "Installing backend/requirements.txt"
  pip install --no-cache-dir -r backend/requirements.txt
fi

if [ -f dashboard/requirements.txt ]; then
  echo "Installing dashboard/requirements.txt"
  pip install --no-cache-dir -r dashboard/requirements.txt
fi

echo "Installing pre-commit hooks if configuration present"
if [ -f .pre-commit-config.yaml ]; then
  pre-commit install --install-hooks || true
fi

printf '\nDev container post-create complete.\n'

echo "Installing k3s"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--docker" sh -
sudo sh -c "k3s server --docker > /var/log/k3s.log 2>&1 &"