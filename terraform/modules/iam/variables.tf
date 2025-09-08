variable "tenancy_ocid" {
  description = "OCI tenancy OCID (required for IAM policies)"
  type        = string
}

variable "compartment_id" {
  description = "OCI compartment ID where resources are located"
  type        = string
}

variable "environment" {
  description = "Environment name (staging, production)"
  type        = string
}
