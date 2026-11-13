#!/usr/bin/env bash
set -Eeuo pipefail

kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
kubectl -n kube-system wait --for=condition=Ready pod -l app=flannel --timeout=600s
