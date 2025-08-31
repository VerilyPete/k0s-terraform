terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
  required_version = ">= 1.5"

  # Backend configuration removed - using local state
  # To use remote state with OCI Object Storage, uncomment and configure:
  # backend "s3" {
  #   bucket                      = "terraform-state-production"
  #   key                         = "k0s-cluster/terraform.tfstate"
  #   region                      = "us-ashburn-1"
  #   endpoint                    = "https://namespace.compat.objectstorage.us-ashburn-1.oraclecloud.com"
  #   skip_region_validation      = true
  #   skip_credentials_validation = true
  #   skip_metadata_api_check     = true
  #   force_path_style           = true
  # }
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
  environment = "production"
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
  tailscale_auth_key    = var.tailscale_auth_key
  environment           = local.environment
  controller_shape_config = var.controller_shape_config
  worker_shape_config   = var.worker_shape_config
  worker_count          = var.worker_count
  storage_size_gb       = var.storage_volumes["worker-storage"].size_gb

  depends_on = [
    module.networking,
    module.storage
  ]
}
