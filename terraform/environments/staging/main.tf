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

  # Backend configuration for OCI Object Storage
  # The endpoint and credentials will be configured via environment variables
  backend "s3" {
    bucket                      = "terraform-state-staging"
    key                         = "k0s-cluster/terraform.tfstate"
    region                      = "us-ashburn-1"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    use_path_style             = true
    # endpoint will be set via AWS_ENDPOINT_URL_S3 environment variable
    # access_key will be set via AWS_ACCESS_KEY_ID environment variable  
    # secret_key will be set via AWS_SECRET_ACCESS_KEY environment variable
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
