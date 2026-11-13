#!/usr/bin/env bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
LOG_FILE="${LOG_FILE:-/var/log/k8s-install.log}"
STATUS_FILE="${STATUS_FILE:-/var/lib/k8s-automation/status}"
KUBERNETES_VERSION="${KUBERNETES_VERSION:-1.31.4}"

log() {
  echo "[$(date -Is)] $*"
}

exec >>"$LOG_FILE" 2>&1

if [ -f /etc/kubernetes/admin.conf ] && kubectl get nodes >/dev/null 2>&1; then
  log "Kubernetes cluster already initialized. Skipping kubeadm init."
  printf '%s\n' "cluster-ready" > "$STATUS_FILE"
  exit 0
fi

log "Initializing Kubernetes cluster with kubeadm"
kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --cri-socket unix:///run/containerd/containerd.sock \
  --kubernetes-version "v${KUBERNETES_VERSION}"

mkdir -p /root/.kube
cp -f /etc/kubernetes/admin.conf /root/.kube/config
chmod 600 /root/.kube/config

mkdir -p /home/ubuntu/.kube
cp -f /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config
chmod 600 /home/ubuntu/.kube/config

export KUBECONFIG=/etc/kubernetes/admin.conf

log "Installing Flannel CNI"
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml

log "Waiting for Flannel pod to become ready"
kubectl -n kube-system wait --for=condition=Ready pod -l app=flannel --timeout=600s

log "Removing control-plane taint to allow scheduling"
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true
kubectl taint nodes --all node-role.kubernetes.io/master- || true

log "Waiting for node to become Ready"
kubectl wait --for=condition=Ready node --all --timeout=600s

log "Verifying system pods"
kubectl -n kube-system rollout status deployment/coredns --timeout=300s
kubectl get pods -A

printf '%s\n' "cluster-ready" > "$STATUS_FILE"
log "Cluster initialization complete"
