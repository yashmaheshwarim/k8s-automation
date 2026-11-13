output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.k8s_lab.id
}

output "public_ip" {
  description = "Public IPv4 address of the EC2 instance"
  value       = aws_instance.k8s_lab.public_ip
}

output "private_ip" {
  description = "Private IPv4 address of the EC2 instance"
  value       = aws_instance.k8s_lab.private_ip
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = var.key_name != "" ? "ssh -o StrictHostKeyChecking=no ubuntu@${aws_instance.k8s_lab.public_ip}" : "ssh access requires an EC2 key pair name in var.key_name"
}

output "kind_cluster_name" {
  description = "Name of the kind cluster created on the instance"
  value       = var.kind_cluster_name
}

output "kubernetes_api_endpoint" {
  description = "Kubernetes API endpoint exposed by the kind cluster"
  value       = "https://${aws_instance.k8s_lab.public_ip}:6443"
}

output "kubeconfig_command" {
  description = "Command to copy the kind kubeconfig from the instance"
  value       = "scp -o StrictHostKeyChecking=no ubuntu@${aws_instance.k8s_lab.public_ip}:/home/ubuntu/.kube/config-remote ./kubeconfig"
}
