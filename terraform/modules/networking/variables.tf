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

variable "k8s_cluster_cidr" {
  description = "CIDR block for Kubernetes cluster communication"
  type        = string
  default     = "10.244.0.0/16"
}

variable "k8s_service_cidr" {
  description = "CIDR block for Kubernetes services"
  type        = string
  default     = "10.96.0.0/12"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  type        = string
  default     = "10.0.1.0/24"
}

# TODO: Re-enable when route rule management is fixed
# variable "route_table_id" {
#   description = "Route table ID to add K8s pod networking routes to"
#   type        = string
# }

variable "worker_private_ips" {
  description = "List of private IPs for K8s worker nodes"
  type        = list(string)
  default     = []
}
