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

variable "route_table_id" {
  description = "Route table ID to read existing routes from and extend with pod networking routes"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID to associate with the new route table"
  type        = string
}

variable "worker_pod_cidrs" {
  description = "Map of worker pod CIDRs to instance IDs for route creation"
  type = map(object({
    pod_cidr    = string
    instance_id = string
  }))
  default = {}
}

variable "worker_private_ips" {
  description = "List of private IPs for k0s worker nodes"
  type        = list(string)
  default     = []
}
