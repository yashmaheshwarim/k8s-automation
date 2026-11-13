#!/usr/bin/env bash
set -Eeuo pipefail

SSH_USER="${SSH_USER:-ubuntu}"
HOST="${1:-}"

if [ -z "$HOST" ]; then
  echo "Usage: $0 <EC2_PUBLIC_IP>" >&2
  exit 1
fi

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "${SSH_USER}@${HOST}" \
  'sudo -n bash -c "kind get clusters && echo && kubectl get nodes -o wide && echo && kubectl get pods -A && echo && kubectl wait --for=condition=Ready node --all --timeout=300s"'
