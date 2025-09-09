variable "compartment_id" {
  description = "OCI compartment ID"
  type        = string
}

variable "availability_domain" {
  description = "OCI availability domain"
  type        = string
}

variable "subnet_id" {
  description = "OCI subnet ID for instances"
  type        = string
}

variable "image_id" {
  description = "Custom image OCID for instances"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for instance access"
  type        = string
}

variable "tailscale_auth_key" {
  description = "Tailscale auth key for networking"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name (staging, production)"
  type        = string
}

variable "controller_shape_config" {
  description = "Shape configuration for controller node"
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
  description = "Shape configuration for worker nodes"
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

variable "storage_volume_ids" {
  description = "Map of storage volume IDs from storage module"
  type        = map(string)
  default     = {}
}

# OCI CCM variables removed - not needed
