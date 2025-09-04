# Local values for environment-specific configuration
locals {
  common_tags = {
    Environment = var.environment
    Project     = "k0s-cluster"
    ManagedBy   = "terraform"
  }
}

# Data sources for existing OCI resources
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

# Storage module
module "storage" {
  source = "../storage"

  compartment_id        = var.compartment_id
  tenancy_ocid         = var.tenancy_ocid
  availability_domain   = var.availability_domain
  environment          = var.environment
  storage_volumes      = var.storage_volumes
  backup_policy_enabled = var.backup_policy_enabled
}

# Compute module
module "compute" {
  source = "../compute"

  compartment_id         = var.compartment_id
  availability_domain    = var.availability_domain
  subnet_id             = var.subnet_id
  image_id              = var.image_id
  ssh_public_key        = var.ssh_public_key
  tailscale_auth_key    = var.tailscale_auth_key
  environment           = var.environment
  controller_shape_config = var.controller_shape_config
  worker_shape_config   = var.worker_shape_config
  worker_count          = var.worker_count
  storage_volume_ids    = module.storage.volume_ids

  depends_on = [
    module.storage
  ]
}

# Networking module for security lists
module "networking" {
  source = "../networking"

  compartment_id      = var.compartment_id
  vcn_id              = var.vcn_id
  environment         = var.environment
  k8s_cluster_cidr    = var.k8s_cluster_cidr
  k8s_service_cidr    = var.k8s_service_cidr
  private_subnet_cidr = var.private_subnet_cidr
  # TODO: Re-enable when route rule management is fixed
  # route_table_id      = var.route_table_id
  worker_private_ips  = module.compute.worker_private_ips

  depends_on = [module.compute]
}
