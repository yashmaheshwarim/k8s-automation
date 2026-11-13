# Kubernetes Automation on AWS

This project provisions a Free Tier eligible single EC2 instance on AWS using Terraform and Ubuntu 24.04, then automatically installs Docker and creates a single-node Kubernetes [kind](https://kind.sigs.k8s.io/) cluster on it. The EC2 User Data bootstrap runs unattended, so the cluster is ready without any manual steps after `terraform apply`.

## Features

- Terraform-managed AWS infrastructure
- Free Tier sized EC2 instance (`t3.micro`, 30 GB gp3 root volume)
- Ubuntu Server 24.04 LTS AMI lookup via Canonical source
- Docker Engine installed automatically
- Single-node Kubernetes cluster created with kind
- kindnet CNI provided by kind (no separate CNI install)
- Public API endpoint on port 6443 with a certificate that includes the instance public IP
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
instance_type = "t3.micro"
root_volume_size = 30
kubernetes_version = "1.31.4"
kind_version = "v0.24.0"
kind_cluster_name = "k8s-lab"
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
- kind cluster name
- Kubernetes API endpoint
- kubeconfig copy command

The instance bootstraps itself: it installs Docker, kubectl and kind, then creates the kind cluster. This usually takes 5-10 minutes on a `t3.micro`.

## Verify the cluster from the local machine

```bash
cd k8s-automation/scripts
./verify-cluster.sh <EC2_PUBLIC_IP>
```

You can also SSH in:

```bash
ssh ubuntu@<EC2_PUBLIC_IP>
sudo tail -f /var/log/k8s-install.log
kind get clusters
kubectl get nodes
kubectl get pods -A
```

## Retrieve kubeconfig

```bash
cd k8s-automation/scripts
./get-kubeconfig.sh <EC2_PUBLIC_IP>
```

This copies `/home/ubuntu/.kube/config` to `./kubeconfig` in the current directory. The server entry already points at `https://<EC2_PUBLIC_IP>:6443`, and the API certificate includes that public IP, so the cluster is reachable from your machine when `kubernetes_api_cidr` allows your IP.

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
- `t3.micro` gives 1 GiB of RAM; a 2 GB swap file is created automatically so the kind control plane fits. Expect slower boot and scheduling than a larger instance.

## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- [docs/INSTALLATION.md](docs/INSTALLATION.md)
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
- [docs/COST-SAFETY.md](docs/COST-SAFETY.md)

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
