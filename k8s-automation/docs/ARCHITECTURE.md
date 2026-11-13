# Architecture Overview

This project creates a single-node Kubernetes lab on AWS that behaves as both a control-plane node and a worker node.

## Infrastructure

The Terraform configuration provisions:

- A dedicated VPC with a public subnet
- An Internet Gateway and route table
- A security group that allows only trusted ingress traffic
- A single EC2 instance running Ubuntu Server 24.04 LTS (amd64)
- A 20 GB gp3 root volume by default

## Kubernetes design

- Cluster type: single-node kubeadm cluster
- Container runtime: containerd
- Kubernetes version: configurable, default 1.31.4
- CNI: Flannel
- Pod network: 10.244.0.0/16
- Node role: control plane + worker
- Taint removal: the default control-plane NoSchedule taint is removed so workloads can schedule

## Network flow

The instance is placed in a public subnet with direct Internet access. Outbound internet access is enabled by default for package downloads and pulling container images. The security group allows:

- SSH from `allowed_ssh_cidr`
- Kubernetes API from `kubernetes_api_cidr`
- Internal cluster node traffic from the same security group
- Egress to 0.0.0.0/0

## Boot process

1. EC2 starts
2. Cloud-init (via EC2 User Data) runs
3. `install-kubernetes.sh` installs dependencies, containerd, and Kubernetes packages
4. `initialize-cluster.sh` runs `kubeadm init`
5. Flannel is installed
6. Node taint is removed and the node becomes Ready
7. The cluster is considered ready only after actual node and pod checks pass

## Why this architecture

This approach keeps the lab simple and cheap while still showing real Kubernetes behavior in a production-like environment. It avoids a multi-node cluster, NAT gateway, ALB, or other paid supporting services.
