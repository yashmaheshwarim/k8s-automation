# Architecture Overview

This project creates a single-node Kubernetes lab on AWS that behaves as both a control-plane node and a worker node.

## Infrastructure

The Terraform configuration provisions:

- A dedicated VPC with a public subnet
- An Internet Gateway and route table
- A security group that allows only trusted ingress traffic
- A single Free Tier eligible `t3.micro` EC2 instance running Ubuntu Server 24.04 LTS (amd64)
- A 30 GB gp3 root volume by default

## Kubernetes design

- Cluster type: single-node kind cluster running inside a Docker container
- Host runtime: Docker Engine (installed during boot)
- Kubernetes version: configurable, default 1.31.4, via the `kindest/node` image
- kind version: configurable, default v0.24.0
- CNI: kindnet, provided by kind
- Node role: control plane + worker (taint removed so workloads can schedule)
- API endpoint: kind binds the API server on `0.0.0.0:6443` and the kubeadm certificate includes the instance public IP

## Network flow

The instance is placed in a public subnet with direct Internet access. Outbound internet access is enabled by default for package downloads and pulling container images. The security group allows:

- SSH from `allowed_ssh_cidr`
- Kubernetes API from `kubernetes_api_cidr`
- Internal cluster node traffic from the same security group
- Egress to 0.0.0.0/0

## Boot process

1. EC2 starts
2. Cloud-init (via EC2 User Data) runs
3. A 2 GB swap file is created, since `t3.micro` only provides 1 GiB of RAM
4. `install-kubernetes.sh` installs Docker Engine, kubectl, and the kind CLI
5. `initialize-cluster.sh` writes `/etc/kind/kind-config.yaml` and runs `kind create cluster`
6. kubeconfig is pointed at the instance public IP and copied to `/home/ubuntu/.kube/config`
7. Node taint is removed, the node becomes Ready, and core DNS is verified
8. The cluster is considered ready only after actual node and pod checks pass

## Why this architecture

This approach keeps the lab simple and cheap while still showing real Kubernetes behavior in a production-like environment. It avoids a multi-node cluster, NAT gateway, ALB, or other paid supporting services.
