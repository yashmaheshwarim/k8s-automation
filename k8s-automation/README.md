# Kubernetes Automation on AWS

This project provisions a single-node Kubernetes lab on AWS EC2 using Terraform and Ubuntu 24.04. It creates a control-plane/worker node, installs containerd, kubeadm, kubelet, kubectl, and Flannel, and leaves you with a ready-to-use cluster for learning DevOps and Kubernetes.

## Features

- Terraform-managed AWS infrastructure
- Ubuntu Server 24.04 LTS AMI lookup via Canonical source
- Single-node Kubernetes cluster using kubeadm
- containerd runtime
- Flannel CNI with Pod CIDR 10.244.0.0/16
- Automatic cluster bootstrap via EC2 User Data
- Security group restricting SSH and Kubernetes API to trusted CIDRs
- Output values for EC2 connection and cluster access

## Repository layout

```text
k8s-automation/
├── terraform/
│   ├── versions.tf
│   ├── provider.tf
│   ├── variables.tf
│   ├── main.tf
│   ├── security-group.tf
│   ├── outputs.tf
│   ├── userdata.sh.tpl
│   ├── terraform.tfvars.example
│   └── .gitignore
├── scripts/
│   ├── install-kubernetes.sh
│   ├── initialize-cluster.sh
│   ├── install-flannel.sh
│   ├── verify-cluster.sh
│   ├── get-kubeconfig.sh
│   └── cleanup-local.sh
├── docs/
│   ├── ARCHITECTURE.md
│   ├── INSTALLATION.md
│   ├── TROUBLESHOOTING.md
│   └── COST-SAFETY.md
├── README.md
├── LICENSE
└── .gitignore
```

## Prerequisites

Before you launch the lab, ensure you have:

- AWS account with permission to create EC2, VPC, and security group resources
- Terraform 1.5+ installed
- AWS CLI configured with credentials or environment variables
- A public IP or trusted CIDR for SSH and Kubernetes API access
- Optional: an existing EC2 key pair name in AWS for SSH access

## Configure variables

Copy the example file and customize it:

```bash
cd k8s-automation/terraform
cp terraform.tfvars.example terraform.tfvars
```

Example:

```hcl
aws_region = "us-east-1"
allowed_ssh_cidr = "203.0.113.10/32"
kubernetes_api_cidr = "203.0.113.10/32"
instance_type = "t3.medium"
root_volume_size = 20
kubernetes_version = "1.31.4"
key_name = ""
```

Important: do not set SSH or Kubernetes API to `0.0.0.0/0` by default. Use your own trusted CIDR or a VPN IP.

## Deploy

```bash
cd k8s-automation/terraform
terraform init
terraform validate
terraform plan
terraform apply
```

After apply, Terraform prints:

- EC2 public IP
- EC2 private IP
- SSH command
- instance ID
- Kubernetes API endpoint

## Verify the cluster from the local machine

```bash
cd k8s-automation/scripts
./verify-cluster.sh <EC2_PUBLIC_IP>
```

You can also SSH in:

```bash
ssh ubuntu@<EC2_PUBLIC_IP>
sudo tail -f /var/log/k8s-install.log
kubectl get nodes
kubectl get pods -A
```

## Retrieve kubeconfig

```bash
cd k8s-automation/scripts
./get-kubeconfig.sh <EC2_PUBLIC_IP>
```

This copies the remote kubeconfig to `./kubeconfig` in the current directory.

## Destroy the lab

```bash
cd k8s-automation/terraform
terraform destroy
```

This removes Terraform-managed infrastructure only. It does not delete unrelated AWS resources you created outside this project state.

## Security notes

- SSH is limited to the `allowed_ssh_cidr` value.
- Kubernetes API is limited to `kubernetes_api_cidr`.
- The lab uses a public subnet with direct Internet access.
- You are responsible for protecting your AWS credentials and SSH keys.
- This lab is intentionally simple and low-cost, but AWS charges may still apply for EC2, EBS, and public IPv4 usage.

## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- [docs/INSTALLATION.md](docs/INSTALLATION.md)
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- [docs/COST-SAFETY.md](docs/COST-SAFETY.md)

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
