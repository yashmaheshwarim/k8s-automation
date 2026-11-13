variable "aws_region" {
  description = "AWS region for the lab."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = length(trimspace(var.aws_region)) > 0
    error_message = "aws_region cannot be blank."
  }
}

variable "instance_type" {
  description = "EC2 instance type for the Kubernetes lab. t3.micro is covered by the AWS Free Tier for eligible accounts."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = length(trimspace(var.instance_type)) > 0
    error_message = "instance_type cannot be blank."
  }
}

variable "root_volume_size" {
  description = "Size in GB for the EC2 root volume. 30 GB gp3 stays within the AWS Free Tier allowance."
  type        = number
  default     = 30

  validation {
    condition     = var.root_volume_size > 0 && var.root_volume_size <= 500
    error_message = "root_volume_size must be greater than 0 and less than or equal to 500 GB."
  }
}

variable "kubernetes_version" {
  description = "Kubernetes version used for the kind node image (kindest/node image tag)."
  type        = string
  default     = "1.31.4"

  validation {
    condition     = can(regex("^1\\.[0-9]+\\.[0-9]+$", var.kubernetes_version))
    error_message = "kubernetes_version must look like 1.31.4."
  }
}

variable "kind_version" {
  description = "kind CLI version installed on the EC2 instance."
  type        = string
  default     = "v0.24.0"

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+$", var.kind_version))
    error_message = "kind_version must look like v0.24.0."
  }
}

variable "kind_cluster_name" {
  description = "Name of the kind cluster created on the EC2 instance."
  type        = string
  default     = "k8s-lab"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.kind_cluster_name))
    error_message = "kind_cluster_name must be a lowercase DNS-1123 name."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the lab VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR."
  }
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrhost(var.public_subnet_cidr, 0))
    error_message = "public_subnet_cidr must be a valid IPv4 CIDR."
  }
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to reach SSH on the EC2 instance."
  type        = string
  default     = "203.0.113.10/32"

  validation {
    condition     = can(cidrhost(var.allowed_ssh_cidr, 0))
    error_message = "allowed_ssh_cidr must be a valid IPv4 CIDR."
  }
}

variable "kubernetes_api_cidr" {
  description = "CIDR allowed to reach the Kubernetes API port 6443."
  type        = string
  default     = "203.0.113.10/32"

  validation {
    condition     = can(cidrhost(var.kubernetes_api_cidr, 0))
    error_message = "kubernetes_api_cidr must be a valid IPv4 CIDR."
  }
}

variable "key_name" {
  description = "Optional EC2 key pair name used for SSH access. Leave blank to skip SSH key attachment."
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Project tag used on all resources."
  type        = string
  default     = "k8s-automation"
}

variable "environment" {
  description = "Environment tag used on all resources."
  type        = string
  default     = "dev"
}
