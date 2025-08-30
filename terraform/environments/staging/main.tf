terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
  required_version = ">= 1.5"

  backend "s3" {
    # Configure for OCI Object Storage backend
    # bucket = "terraform-state-staging"
    # key    = "k0s-cluster/terraform.tfstate"
    # region = "us-ashburn-1"
    # endpoint = "https://namespace.compat.objectstorage.us-ashburn-1.oraclecloud.com"
  }
}

# Provider configuration
provider "oci" {
  # Configuration will come from environment variables or instance principal
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
  environment         = local.environment
  k8s_cluster_cidr    = var.k8s_cluster_cidr
  k8s_service_cidr    = var.k8s_service_cidr
  private_subnet_cidr = var.private_subnet_cidr
}

# Storage module
module "storage" {
  source = "../../modules/storage"

  compartment_id        = var.compartment_id
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
