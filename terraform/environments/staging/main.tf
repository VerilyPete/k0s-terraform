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

# Data sources for existing OCI resources
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

# Local values for environment-specific configuration
locals {
  environment = "staging"
  common_tags = {
    Environment = local.environment
    Project     = "k0s-cluster"
    ManagedBy   = "terraform"
  }
}

# Networking module
module "networking" {
  source = "../../modules/networking"

  compartment_id      = var.compartment_id
  vcn_id              = var.vcn_id
  environment         = local.environment
  k8s_cluster_cidr    = var.k8s_cluster_cidr
  k8s_service_cidr    = var.k8s_service_cidr
  private_subnet_cidr = var.private_subnet_cidr
}

# Storage module
module "storage" {
  source = "../../modules/storage"

  compartment_id        = var.compartment_id
  tenancy_ocid         = var.tenancy_ocid
  availability_domain   = var.availability_domain
  environment          = local.environment
  storage_volumes      = var.storage_volumes
  backup_policy_enabled = var.backup_policy_enabled
}

# Compute module
module "compute" {
  source = "../../modules/compute"

  compartment_id         = var.compartment_id
  availability_domain    = var.availability_domain
  subnet_id             = var.subnet_id
  image_id              = var.image_id
  ssh_public_key        = var.ssh_public_key
# ssh_private_key removed - no longer using provisioners
  tailscale_auth_key    = var.tailscale_auth_key
  environment           = local.environment
  controller_shape_config = var.controller_shape_config
  worker_shape_config   = var.worker_shape_config
  worker_count          = var.worker_count
  storage_volume_ids    = module.storage.volume_ids

  depends_on = [
    module.networking,
    module.storage
  ]
}
