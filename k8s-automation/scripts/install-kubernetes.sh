#!/usr/bin/env bash
set -Eeuo pipefail

export DEBIAN_FRONTEND=noninteractive
LOG_FILE="${LOG_FILE:-/var/log/k8s-install.log}"
STATUS_FILE="${STATUS_FILE:-/var/lib/k8s-automation/status}"
KUBERNETES_VERSION="${KUBERNETES_VERSION:-1.31.4}"
KUBERNETES_MINOR="${KUBERNETES_VERSION%.*}"

log() {
  echo "[$(date -Is)] $*"
}

mkdir -p /var/lib/k8s-automation
mkdir -p /etc/apt/keyrings

exec >>"$LOG_FILE" 2>&1

log "Starting Kubernetes installation for version ${KUBERNETES_VERSION}"

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
curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_MINOR}:/deb/Release.key" | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_MINOR}:/deb/ /
EOF
apt-get update

log "Installing kubelet, kubeadm and kubectl"
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

log "Enabling kubelet"
systemctl enable kubelet --now

printf '%s\n' "install-complete" > "$STATUS_FILE"
log "Kubernetes packages installed successfully"
