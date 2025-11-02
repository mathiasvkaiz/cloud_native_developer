#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_DIR="${DEVCONTAINER_PROJECT_ROOT:-$(pwd)}"
cd "$WORKSPACE_DIR"

# Git config and credential manager
git config --global user.email "mathias@vkaiz.de"
git config --global user.name "mvk"
gh auth login

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

echo "Installing hetzner cli"
curl -sSLO https://github.com/hetznercloud/cli/releases/latest/download/hcloud-linux-amd64.tar.gz
sudo tar -C /usr/local/bin --no-same-owner -xzf hcloud-linux-amd64.tar.gz hcloud
rm hcloud-linux-amd64.tar.gz

echo "Installing vagrant"
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install vagrant