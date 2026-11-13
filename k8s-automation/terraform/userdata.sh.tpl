#!/bin/bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
export LOG_FILE="/var/log/k8s-install.log"
export STATUS_FILE="/var/lib/k8s-automation/status"
export KUBERNETES_VERSION="${kubernetes_version}"
export KIND_VERSION="${kind_version}"
export KIND_CLUSTER_NAME="${kind_cluster_name}"

mkdir -p /var/lib/k8s-automation
mkdir -p /opt/k8s-automation
mkdir -p /etc/kind

exec > >(tee -a "$LOG_FILE") 2>&1

echo "[$(date -Is)] Starting kind bootstrap"

cat <<'SCRIPT_INSTALL' >/opt/k8s-automation/install-kubernetes.sh
#!/usr/bin/env bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
LOG_FILE="$${LOG_FILE:-/var/log/k8s-install.log}"
STATUS_FILE="$${STATUS_FILE:-/var/lib/k8s-automation/status}"
KUBERNETES_VERSION="$${KUBERNETES_VERSION:-1.31.4}"
KIND_VERSION="$${KIND_VERSION:-v0.24.0}"

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

log "Installing kubectl v$${KUBERNETES_VERSION}"
curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/v$${KUBERNETES_VERSION}/bin/linux/amd64/kubectl"
curl -fsSLo /tmp/kubectl.sha256 "https://dl.k8s.io/release/v$${KUBERNETES_VERSION}/bin/linux/amd64/kubectl.sha256"
echo "$(cat /tmp/kubectl.sha256)  /usr/local/bin/kubectl" | sha256sum --check
chmod 0755 /usr/local/bin/kubectl
kubectl version --client

log "Installing kind $${KIND_VERSION}"
curl -fsSLo /usr/local/bin/kind "https://kind.sigs.k8s.io/dl/$${KIND_VERSION}/kind-linux-amd64"
chmod +x /usr/local/bin/kind
kind version

printf '%s\n' "install-complete" > "$STATUS_FILE"
log "kind prerequisites installed successfully"
SCRIPT_INSTALL

cat <<'SCRIPT_INIT' >/opt/k8s-automation/initialize-cluster.sh
#!/usr/bin/env bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
LOG_FILE="$${LOG_FILE:-/var/log/k8s-install.log}"
STATUS_FILE="$${STATUS_FILE:-/var/lib/k8s-automation/status}"
KUBERNETES_VERSION="$${KUBERNETES_VERSION:-1.31.4}"
KIND_CLUSTER_NAME="$${KIND_CLUSTER_NAME:-k8s-lab}"
KIND_CONFIG_FILE="/etc/kind/kind-config.yaml"

log() {
  echo "[$(date -Is)] $*"
}

exec >>"$LOG_FILE" 2>&1

export KUBECONFIG=/root/.kube/config

if kind get clusters 2>/dev/null | grep -qx "$KIND_CLUSTER_NAME"; then
  log "kind cluster $KIND_CLUSTER_NAME already exists. Skipping creation."
  printf '%s\n' "cluster-ready" > "$STATUS_FILE"
  exit 0
fi

log "Discovering instance public IP for the API server certificate"
IMDS_TOKEN="$(curl -sX PUT -H 'X-aws-ec2-metadata-token-ttl-seconds: 21600' http://169.254.169.254/latest/api/token || true)"
PUBLIC_IP="$(curl -s -H "X-aws-ec2-metadata-token: $${IMDS_TOKEN}" http://169.254.169.254/latest/meta-data/public-ipv4 || true)"
if ! printf '%s' "$PUBLIC_IP" | grep -Eq '^[0-9]+(\.[0-9]+){3}$'; then
  log "Could not read a public IPv4 address from instance metadata; falling back to 127.0.0.1"
  PUBLIC_IP="127.0.0.1"
fi
log "Using $${PUBLIC_IP} as the API server address"

log "Writing kind cluster configuration"
mkdir -p /etc/kind
cat <<EOF >"$KIND_CONFIG_FILE"
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: $KIND_CLUSTER_NAME
networking:
  apiServerAddress: "0.0.0.0"
  apiServerPort: 6443
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: ClusterConfiguration
        apiServer:
          certSANs:
            - "127.0.0.1"
            - "localhost"
            - "$PUBLIC_IP"
EOF

log "Creating kind cluster $KIND_CLUSTER_NAME with kindest/node:v$${KUBERNETES_VERSION}"
kind create cluster \
  --name "$KIND_CLUSTER_NAME" \
  --image "kindest/node:v$${KUBERNETES_VERSION}" \
  --config "$KIND_CONFIG_FILE" \
  --wait 600s

log "Configuring kubeconfig for local and remote access"
kubectl config set-cluster "kind-$KIND_CLUSTER_NAME" --server="https://127.0.0.1:6443" >/dev/null

mkdir -p /home/ubuntu/.kube
cp -f /root/.kube/config /home/ubuntu/.kube/config
cp -f /root/.kube/config /home/ubuntu/.kube/config-remote
kubectl config set-cluster "kind-$KIND_CLUSTER_NAME" \
  --server="https://$${PUBLIC_IP}:6443" \
  --kubeconfig=/home/ubuntu/.kube/config-remote >/dev/null
chown -R ubuntu:ubuntu /home/ubuntu/.kube
chmod 600 /home/ubuntu/.kube/config /home/ubuntu/.kube/config-remote

log "Removing control-plane taint to allow workloads to schedule"
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true

log "Waiting for the kind node to become Ready"
kubectl wait --for=condition=Ready node --all --timeout=600s

log "Verifying system pods"
kubectl -n kube-system rollout status deployment/coredns --timeout=300s
kubectl get nodes -o wide
kubectl get pods -A

printf '%s\n' "cluster-ready" > "$STATUS_FILE"
log "kind cluster initialization complete"
SCRIPT_INIT

chmod +x /opt/k8s-automation/install-kubernetes.sh /opt/k8s-automation/initialize-cluster.sh

/opt/k8s-automation/install-kubernetes.sh
/opt/k8s-automation/initialize-cluster.sh

echo "[$(date -Is)] kind cluster bootstrap completed successfully"
