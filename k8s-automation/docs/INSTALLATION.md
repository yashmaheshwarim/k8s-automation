# Installation Guide

This guide explains how to deploy and verify the Kubernetes lab.

## 1. Requirements

- Terraform 1.5+
- AWS CLI configured
- IAM permissions to create EC2, VPC, Internet Gateway, security group, and EBS resources
- A trusted public IP/CIDR for SSH and the Kubernetes API

## 2. Prepare environment

```bash
cd k8s-automation/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your AWS region and your home public IP (or VPN range). Example:

```hcl
aws_region = "us-east-1"
allowed_ssh_cidr = "203.0.113.10/32"
kubernetes_api_cidr = "203.0.113.10/32"
instance_type = "t3.medium"
root_volume_size = 20
kubernetes_version = "1.31.4"
key_name = ""
```

## 3. Validate and deploy

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

## 4. Observe installation output

After the instance is launched, Cloud-init executes automatically. The bootstrap logs are written to:

```bash
/var/log/k8s-install.log
```

You can watch it from the instance:

```bash
ssh ubuntu@<EC2_PUBLIC_IP>
sudo tail -f /var/log/k8s-install.log
```

## 5. Check cluster readiness

From a local machine:

```bash
cd ../scripts
./verify-cluster.sh <EC2_PUBLIC_IP>
```

Remote shell checks:

```bash
kubectl get nodes
kubectl get pods -A
kubectl wait --for=condition=Ready node --all --timeout=600s
```

## 6. Retrieve kubeconfig

```bash
cd ../scripts
./get-kubeconfig.sh <EC2_PUBLIC_IP>
```

This copies `/home/ubuntu/.kube/config` to the current directory as `kubeconfig`.

## 7. Destroy the environment

```bash
cd ../terraform
terraform destroy
```

## 8. Post-deploy notes

- The cluster is intentionally single-node and optimized for labs.
- To avoid insecure exposure, keep SSH and Kubernetes API restricted to a known trusted CIDR.
- Re-run `terraform apply` only after updating values in `terraform.tfvars`.
