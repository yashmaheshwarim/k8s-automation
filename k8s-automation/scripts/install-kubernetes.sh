#!/usr/bin/env bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
LOG_FILE="${LOG_FILE:-/var/log/k8s-install.log}"
STATUS_FILE="${STATUS_FILE:-/var/lib/k8s-automation/status}"
KUBERNETES_VERSION="${KUBERNETES_VERSION:-1.31.4}"
KIND_VERSION="${KIND_VERSION:-v0.24.0}"

log() {
  echo "[$(date -Is)] $*"
}

mkdir -p /var/lib/k8s-automation /etc/apt/keyrings

exec >>"$LOG_FILE" 2>&1

log "Starting kind prerequisites installation"

if ! grep -Eq 'ubuntu' /etc/os-release 2>/dev/null; then
  log "This script expects Ubuntu 24.04 or a compatible Ubuntu-based system"
  exit 1
fi

log "Updating apt packages"
apt-get update
apt-get install -y ca-certificates curl gnupg apt-transport-https

log "Adding 2G swap file for small free tier instances"
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >>/etc/fstab
fi

log "Installing Docker Engine"
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
cat <<EOF >/etc/apt/sources.list.d/docker.list
deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable
EOF
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
usermod -aG docker ubuntu

log "Installing kubectl v${KUBERNETES_VERSION}"
curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/v${KUBERNETES_VERSION}/bin/linux/amd64/kubectl"
curl -fsSLo /tmp/kubectl.sha256 "https://dl.k8s.io/release/v${KUBERNETES_VERSION}/bin/linux/amd64/kubectl.sha256"
echo "$(cat /tmp/kubectl.sha256)  /usr/local/bin/kubectl" | sha256sum --check
chmod 0755 /usr/local/bin/kubectl
kubectl version --client

log "Installing kind ${KIND_VERSION}"
curl -fsSLo /usr/local/bin/kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64"
chmod +x /usr/local/bin/kind
kind version

printf '%s\n' "install-complete" > "$STATUS_FILE"
log "kind prerequisites installed successfully"
