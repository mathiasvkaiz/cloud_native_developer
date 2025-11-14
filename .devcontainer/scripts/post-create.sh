#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_DIR="${DEVCONTAINER_PROJECT_ROOT:-$(pwd)}"
cd "$WORKSPACE_DIR"

# Cleaing up vscode tmp files to avoid rror: Cannot find module '/tmp/vscode-remote-containers-cc57362c-0efb-491a-b656-4c3bf00af616.js'
echo "Cleaning up old VS Code remote server temp files and cache..."
sudo rm -rf /tmp/vscode-remote-containers* ~/.vscode-server /vscode/vscode-server || true

# Disable Docker credential helper (fixes token storage crash)
echo "Configuring Docker credential store"
mkdir -p ~/.docker
cat << 'EOF' > ~/.docker/config.json
{
  "credsStore": ""
}
EOF

# Load env variables
if [ -f "$WORKSPACE_DIR/.env" ]; then
  echo "Loading .env variables"
  set -a
  source "$WORKSPACE_DIR/.env"
  set +a
fi

# Git config and credential manager
echo "Configuring gh cli"
git config --global user.email "mathias@vkaiz.de"
git config --global user.name "mvk"

echo "Using token-based GitHub auth"
gh auth status

echo "Logging into docker registry"
echo "$DOCKER_TOKEN" | docker login --username "$DOCKER_USER" --password-stdin

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

echo "Installing k3d"
sudo apt update
sudo apt install -y socat conntrack
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

echo "Installing k3d"
sudo apt update
sudo apt install -y socat conntrack
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

if k3d cluster list -o json | jq -e '.[] | select(.name == "devcluster")' > /dev/null; then
  echo "k3d cluster 'devcluster' already exists, skipping creation."
else
  echo "Creating k3d cluster 'devcluster'..."
  k3d cluster create devcluster \
    --api-port 6443 \
    --servers 1 \
    --agents 0 \
    -p "8080:80@loadbalancer" \
    -p "8443:443@loadbalancer"
  
  kubectl create namespace argocd
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

  kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
  kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
fi

# Install ArgoCD cli
mkdir -p ~/.local/bin
curl -sSL -o ~/.local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x ~/.local/bin/argocd
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

# Install Homebrew silently
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo >> /home/vscode/.bashrc
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/vscode/.bashrc
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"