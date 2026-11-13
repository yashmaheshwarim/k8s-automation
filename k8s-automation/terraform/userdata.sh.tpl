#!/bin/bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
export LOG_FILE="/var/log/k8s-install.log"
export STATUS_FILE="/var/lib/k8s-automation/status"
export KUBERNETES_VERSION="${kubernetes_version}"

mkdir -p /var/lib/k8s-automation
mkdir -p /opt/k8s-automation

exec > >(tee -a "$LOG_FILE") 2>&1

echo "[$(date -Is)] Starting Kubernetes bootstrap"

cat <<'SCRIPT_INSTALL' >/opt/k8s-automation/install-kubernetes.sh
#!/usr/bin/env bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
LOG_FILE="$${LOG_FILE:-/var/log/k8s-install.log}"
STATUS_FILE="$${STATUS_FILE:-/var/lib/k8s-automation/status}"
KUBERNETES_VERSION="$${KUBERNETES_VERSION:-1.31.4}"
KUBERNETES_MINOR="$${KUBERNETES_VERSION%.*}"

log() {
  echo "[$(date -Is)] $*"
}

mkdir -p /var/lib/k8s-automation
mkdir -p /etc/apt/keyrings

exec >>"$LOG_FILE" 2>&1

log "Starting Kubernetes installation for version $${KUBERNETES_VERSION}"

if ! grep -Eq 'ubuntu' /etc/os-release 2>/dev/null; then
  log "This script expects Ubuntu 24.04 or a compatible Ubuntu-based system"
  exit 1
fi

log "Updating apt packages"
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gpg software-properties-common

log "Disabling swap and adjusting fstab"
swapoff -a || true
if grep -Eq '\sswap\s' /etc/fstab; then
  sed -ri '/\sswap\s/s/^#?/#/' /etc/fstab
fi

log "Loading kernel modules"
modprobe overlay
modprobe br_netfilter
cat <<'EOF' >/etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

log "Configuring sysctl for Kubernetes networking"
cat <<'EOF' >/etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --system >/dev/null

log "Installing containerd"
apt-get install -y containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl enable --now containerd
systemctl restart containerd

log "Installing Kubernetes repository"
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v$${KUBERNETES_MINOR}:/deb/Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$${KUBERNETES_MINOR}:/deb/ /
EOF
apt-get update

log "Installing kubelet, kubeadm and kubectl"
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

log "Enabling kubelet"
systemctl enable kubelet --now

printf '%s\n' "install-complete" > "$${STATUS_FILE}"
log "Kubernetes packages installed successfully"
SCRIPT_INSTALL

cat <<'SCRIPT_INIT' >/opt/k8s-automation/initialize-cluster.sh
#!/usr/bin/env bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
LOG_FILE="$${LOG_FILE:-/var/log/k8s-install.log}"
STATUS_FILE="$${STATUS_FILE:-/var/lib/k8s-automation/status}"
KUBERNETES_VERSION="$${KUBERNETES_VERSION:-1.31.4}"

log() {
  echo "[$(date -Is)] $*"
}

exec >>"$${LOG_FILE}" 2>&1

if [ -f /etc/kubernetes/admin.conf ] && kubectl get nodes >/dev/null 2>&1; then
  log "Kubernetes cluster already initialized. Skipping kubeadm init."
  printf '%s\n' "cluster-ready" > "$${STATUS_FILE}"
  exit 0
fi

log "Initializing Kubernetes cluster with kubeadm"
kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --cri-socket unix:///run/containerd/containerd.sock \
  --kubernetes-version "v$${KUBERNETES_VERSION}"

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

printf '%s\n' "cluster-ready" > "$${STATUS_FILE}"
log "Cluster initialization complete"
SCRIPT_INIT

chmod +x /opt/k8s-automation/install-kubernetes.sh /opt/k8s-automation/initialize-cluster.sh

/opt/k8s-automation/install-kubernetes.sh
/opt/k8s-automation/initialize-cluster.sh

echo "[$(date -Is)] Kubernetes lab bootstrap completed successfully"
