variable "compartment_id" {
  description = "OCI compartment ID"
  type        = string
}

variable "vcn_id" {
  description = "OCI VCN ID where the security list will be created"
  type        = string
}

variable "environment" {
  description = "Environment name (staging, production)"
  type        = string
}

variable "k0s_cluster_cidr" {
  description = "CIDR block for Kubernetes cluster communication"
  type        = string
  default     = "10.244.0.0/16"
}

variable "k0s_service_cidr" {
  description = "CIDR block for Kubernetes services"
  type        = string
  default     = "10.96.0.0/12"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_id" {
  description = "Subnet ID for reference (route table approach not supported)"
  type        = string
}

# Removed route_table_id and worker_pod_cidrs variables
# OCI route tables cannot target instances directly

variable "worker_private_ips" {
  description = "List of private IPs for k0s worker nodes"
  type        = list(string)
  default     = []
}
