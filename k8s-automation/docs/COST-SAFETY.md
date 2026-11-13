# Cost and Security Safeguards

This lab is designed to remain inexpensive and intentionally minimal. It is built for learning, not production workloads.

## Cost-aware design choices

- Single EC2 instance only
- No NAT Gateway
- No Application Load Balancer
- No Elastic IP unless you explicitly add one
- No extra compute resources beyond the lab node
- Configurable instance type and disk size
- Public subnet for direct access during the lab

## AWS charging considerations

Costs can still apply for:

- EC2 instance runtime
- EBS root volume and storage usage
- Public IPv4 addresses
- Data transfer and outbound traffic
- AWS region differences in pricing

Free Tier eligibility depends on:

- the AWS account creation date
- the current Free Tier offer available to that account
- region-specific rules
- the selected instance type and usage period
- current limits and exclusions

Do not assume that `t3.medium` is automatically Free Tier eligible. Sometimes a region or account might still be ineligible even when the instance type is typically low-cost.

## Security safeguards

- SSH is only allowed from `allowed_ssh_cidr`
- Kubernetes API is only allowed from `kubernetes_api_cidr`
- The default configuration avoids `0.0.0.0/0` exposure for SSH and API access
- The project creates only Terraform-managed resources in its state
- You are responsible for protecting your AWS credentials, SSH keys, and Terraform state files

## Important disclaimer

`terraform destroy` only removes resources tracked in the Terraform state for this project. It cannot delete AWS resources that were created manually outside of this project state.
