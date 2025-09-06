terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 7.15"  # Latest as of August 2025
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"  # Updated to modern version
    }
  }
  required_version = ">= 1.12.0"  # Require Terraform with OCI backend support

  # Backend configuration using OCI native backend
  # Note: Variables cannot be used in backend blocks - must use literal values
  # Using partial configuration - namespace and region set via -backend-config
  backend "oci" {
    bucket              = "terraform-state-staging"
    key                 = "k0s-cluster/terraform.tfstate"
    auth                = "APIKey"
    config_file_profile = "DEFAULT"
  }
}

# Provider configuration
provider "oci" {
  # Use file-based authentication
  auth                = "APIKey"
  tenancy_ocid        = var.tenancy_ocid
  user_ocid           = var.user_ocid  
  fingerprint         = var.fingerprint
  private_key_path    = var.private_key_path
  region              = var.region
}

# K0s environment module
module "k0s_environment" {
  source = "../../modules/k0s-environment"

  # Environment identification
  environment = "staging"

  # OCI Provider Configuration
  tenancy_ocid       = var.tenancy_ocid
  oci_namespace      = var.oci_namespace
  user_ocid          = var.user_ocid
  fingerprint        = var.fingerprint
  private_key_path   = var.private_key_path
  region             = var.region
  compartment_id     = var.compartment_id
  availability_domain = var.availability_domain

  # Infrastructure Configuration
  subnet_id       = var.subnet_id
  vcn_id          = var.vcn_id
  route_table_id  = var.route_table_id
  image_id        = var.image_id

  # Access Configuration
  ssh_public_key     = var.ssh_public_key
  tailscale_auth_key = var.tailscale_auth_key

  # Network Configuration
  k8s_cluster_cidr    = var.k8s_cluster_cidr
  k8s_service_cidr    = var.k8s_service_cidr
  private_subnet_cidr = var.private_subnet_cidr

  # Instance Configuration
  controller_shape_config = var.controller_shape_config
  worker_shape_config     = var.worker_shape_config
  worker_count           = var.worker_count

  # Storage Configuration
  storage_volumes       = var.storage_volumes
  backup_policy_enabled = var.backup_policy_enabled
}