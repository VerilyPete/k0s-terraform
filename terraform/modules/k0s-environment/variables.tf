# Environment Configuration
variable "environment" {
  description = "Environment name (staging, production)"
  type        = string
  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Environment must be either 'staging' or 'production'."
  }
}

# OCI Provider Configuration Variables
variable "tenancy_ocid" {
  description = "OCI tenancy OCID"
  type        = string
}

variable "oci_namespace" {
  description = "OCI Object Storage namespace for backend configuration"
  type        = string
}

variable "user_ocid" {
  description = "OCI user OCID"
  type        = string
}

variable "fingerprint" {
  description = "OCI API key fingerprint"
  type        = string
}

variable "private_key_path" {
  description = "Path to OCI API private key file"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "OCI region"
  type        = string
}

variable "compartment_id" {
  description = "OCI compartment ID"
  type        = string
}

variable "availability_domain" {
  description = "OCI availability domain"
  type        = string
}

variable "subnet_id" {
  description = "OCI private subnet ID"
  type        = string
}

variable "vcn_id" {
  description = "OCI VCN ID (still needed for security lists)"
  type        = string
}

variable "route_table_id" {
  description = "Route table ID for the private subnet (to add pod networking routes)"
  type        = string
}

variable "image_id" {
  description = "Custom image OCID"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
}

variable "tailscale_auth_key" {
  description = "Tailscale auth key"
  type        = string
  sensitive   = true
}

# Kubernetes Network Configuration
variable "k0s_cluster_cidr" {
  description = "CIDR block for Kubernetes pods"
  type        = string
  default     = "10.244.0.0/16"
}

variable "k0s_service_cidr" {
  description = "CIDR block for Kubernetes services"
  type        = string
  default     = "10.96.0.0/12"
}

variable "private_subnet_cidr" {
  description = "CIDR block for private subnet"
  type        = string
  default     = "10.0.1.0/24"
}

# Instance Configuration
variable "controller_shape_config" {
  description = "Controller node shape configuration"
  type = object({
    ocpus     = number
    memory_gb = number
  })
  default = {
    ocpus     = 1
    memory_gb = 6
  }
}

variable "worker_shape_config" {
  description = "Worker node shape configuration"
  type = object({
    ocpus     = number
    memory_gb = number
  })
  default = {
    ocpus     = 1
    memory_gb = 6
  }
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

# Storage Configuration
variable "storage_volumes" {
  description = "Storage volume configurations"
  type = map(object({
    size_gb      = number
    display_name = string
    description  = string
  }))
  default = {
    "worker-storage" = {
      size_gb      = 50
      display_name = "k0s-worker-1-data"
      description  = "Primary storage for worker-1 with persistent volumes"
    }
  }
}

variable "backup_policy_enabled" {
  description = "Enable backup policy for volumes"
  type        = bool
  default     = true
}
