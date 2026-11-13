#!/usr/bin/env bash
set -Eeuo pipefail

SSH_USER="${SSH_USER:-ubuntu}"
HOST="${1:-}"

if [ -z "$HOST" ]; then
  echo "Usage: $0 <EC2_PUBLIC_IP>" >&2
  exit 1
fi

scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${SSH_USER}@${HOST}:/home/ubuntu/.kube/config" ./kubeconfig
chmod 600 ./kubeconfig
printf 'Kubeconfig saved to %s\n' "$(pwd)/kubeconfig"
