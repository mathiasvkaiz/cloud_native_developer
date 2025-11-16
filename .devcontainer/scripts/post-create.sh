#!/usr/bin/env bash
set -euo pipefail

WORKSPACE_DIR="${DEVCONTAINER_PROJECT_ROOT:-$(pwd)}"
cd "$WORKSPACE_DIR"

echo "==> Cleaning up VS Code server temp files..."
sudo rm -rf /tmp/vscode-remote-containers* || true
sudo rm -rf ~/.vscode-server || true
sudo rm -rf /vscode/vscode-server 2>/dev/null || true

echo "==> Disabling Docker credential helper..."
mkdir -p ~/.docker
cat << 'EOF' > ~/.docker/config.json
{
  "credsStore": ""
}
EOF

# --- Load .env ---------------------------------------------------------
if [ -f "$WORKSPACE_DIR/.env" ]; then
  echo "==> Loading .env variables"
  set -a
  source "$WORKSPACE_DIR/.env" || echo "Warning: failed to source .env"
  set +a
fi

# --- Git + GH ----------------------------------------------------------
echo "==> Configuring Git credentials"
git config --global user.email "mathias@vkaiz.de"
git config --global user.name "mvk"

echo "==> Checking GitHub authentication"
gh auth status || echo "Warning: gh not authenticated"

# --- Docker Login ------------------------------------------------------
if [[ -n "${DOCKER_TOKEN:-}" ]]; then
  echo "==> Logging into Docker registry"
  echo "$DOCKER_TOKEN" | docker login --username "$DOCKER_USER" --password-stdin
else
  echo "Warning: DOCKER_TOKEN not set — skipping Docker login."
fi

# --- Install Python dependencies --------------------------------------
install_reqs() {
  local file="$1"
  if [ -f "$file" ]; then
    echo "==> Installing $file"
    pip install --no-cache-dir -r "$file"
  fi
}

install_reqs requirements.txt
install_reqs requirements-dev.txt
install_reqs backend/requirements.txt
install_reqs dashboard/requirements.txt

# --- Pre-commit --------------------------------------------------------
if [ -f .pre-commit-config.yaml ]; then
  echo "==> Installing pre-commit hooks"
  pre-commit install --install-hooks || true
fi

printf '\n==> Dev container post-create complete.\n\n'

# --- Install k3d -------------------------------------------------------
echo "==> Installing k3d + dependencies"
sudo apt update -y
sudo apt install -y socat conntrack jq

curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# --- Create cluster (if not exists) -----------------------------------
if k3d cluster list -o json | jq -e '.[] | select(.name == "devcluster")' > /dev/null; then
  echo "==> k3d cluster 'devcluster' already exists"
else
  echo "==> Creating k3d cluster 'devcluster'..."
  k3d cluster create devcluster \
    --api-port 6443 \
    --servers 1 \
    --agents 0 \
    -p "8080:32080@server:0" \
    -p "8443:32443@server:0"

  kubectl create namespace argocd
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

  echo "==> Waiting for ArgoCD pods to be ready..."
  kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

  echo "==> Patching ArgoCD service to NodePort for direct access"
  kubectl patch svc argocd-server -n argocd -p '
  {
    "spec": {
      "type": "NodePort",
      "ports": [
        {
          "name": "http",
          "port": 80,
          "nodePort": 32080,
          "targetPort": 8080
        },
        {
          "name": "https",
          "port": 443,
          "nodePort": 32443,
          "targetPort": 8080
        }
      ]
    }
  }'
fi

# --- Install ArgoCD CLI ------------------------------------------------
echo "==> Installing ArgoCD CLI"

mkdir -p ~/.local/bin

ARCH=$(uname -m)
case "$ARCH" in
  x86_64)
    ARGOCD_BINARY="argocd-linux-amd64"
    ;;
  aarch64|arm64)
    ARGOCD_BINARY="argocd-linux-arm64"
    ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

curl -sSL -o ~/.local/bin/argocd \
  "https://github.com/argoproj/argo-cd/releases/latest/download/${ARGOCD_BINARY}"

chmod +x ~/.local/bin/argocd

# Add PATH once
if ! grep -q 'HOME/.local/bin' ~/.bashrc; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
fi

# --- Install Homebrew --------------------------------------------------
echo "==> Installing Homebrew"
NONINTERACTIVE=1 /bin/bash -c \
  "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

if ! grep -q "linuxbrew" /home/vscode/.bashrc; then
  {
    echo
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
  } >> /home/vscode/.bashrc
fi

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

echo "==> Setup complete 🎉"