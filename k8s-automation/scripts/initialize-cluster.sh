#!/usr/bin/env bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
LOG_FILE="${LOG_FILE:-/var/log/k8s-install.log}"
STATUS_FILE="${STATUS_FILE:-/var/lib/k8s-automation/status}"
KUBERNETES_VERSION="${KUBERNETES_VERSION:-1.31.4}"
KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-k8s-lab}"
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
PUBLIC_IP="$(curl -s -H "X-aws-ec2-metadata-token: ${IMDS_TOKEN}" http://169.254.169.254/latest/meta-data/public-ipv4 || true)"
if ! printf '%s' "$PUBLIC_IP" | grep -Eq '^[0-9]+(\.[0-9]+){3}$'; then
  log "Could not read a public IPv4 address from instance metadata; falling back to 127.0.0.1"
  PUBLIC_IP="127.0.0.1"
fi
log "Using ${PUBLIC_IP} as the API server address"

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

log "Creating kind cluster $KIND_CLUSTER_NAME with kindest/node:v${KUBERNETES_VERSION}"
kind create cluster \
  --name "$KIND_CLUSTER_NAME" \
  --image "kindest/node:v${KUBERNETES_VERSION}" \
  --config "$KIND_CONFIG_FILE" \
  --wait 600s

log "Configuring kubeconfig for local and remote access"
kubectl config set-cluster "kind-$KIND_CLUSTER_NAME" --server="https://127.0.0.1:6443" >/dev/null

mkdir -p /home/ubuntu/.kube
cp -f /root/.kube/config /home/ubuntu/.kube/config
cp -f /root/.kube/config /home/ubuntu/.kube/config-remote
kubectl config set-cluster "kind-$KIND_CLUSTER_NAME" \
  --server="https://${PUBLIC_IP}:6443" \
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
