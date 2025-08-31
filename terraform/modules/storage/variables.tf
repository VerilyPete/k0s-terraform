variable "compartment_id" {
  description = "OCI compartment ID"
  type        = string
}

variable "tenancy_ocid" {
  description = "OCI tenancy OCID"
  type        = string
}

variable "availability_domain" {
  description = "OCI availability domain"
  type        = string
}

variable "environment" {
  description = "Environment name (staging, production)"
  type        = string
}

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
      display_name = "k8s-worker-1-data"
      description  = "Primary storage for worker-1 with persistent volumes"
    }
  }
}

variable "backup_policy_enabled" {
  description = "Enable automatic backup policy for volumes"
  type        = bool
  default     = true
}
