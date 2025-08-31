# Data source for availability domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

# Data source for default backup policies - try root compartment first
data "oci_identity_tenancy" "current" {
  tenancy_id = var.tenancy_ocid
}

# Look for backup policies in the tenancy root compartment
data "oci_core_volume_backup_policies" "default_backup_policies" {
  compartment_id = data.oci_identity_tenancy.current.id

  filter {
    name   = "display_name"
    values = ["bronze", "Bronze", "silver", "Silver", "gold", "Gold"]
  }
}

# Storage volumes
resource "oci_core_volume" "storage_volumes" {
  for_each = var.storage_volumes

  compartment_id      = var.compartment_id
  availability_domain = var.availability_domain
  display_name        = "${each.value.display_name}-${var.environment}"
  size_in_gbs         = each.value.size_gb
  
  # Ensure volume type is specified (default is usually iscsi)
  vpus_per_gb = 10  # Default performance tier
  
  freeform_tags = {
    "Environment" = var.environment
    "Purpose"     = each.value.description
    "ManagedBy"   = "terraform"
    "Volume"      = each.key
  }
}

# Backup policy assignment (optional) - only if backup policies are found
resource "oci_core_volume_backup_policy_assignment" "backup_assignment" {
  for_each = var.backup_policy_enabled && length(data.oci_core_volume_backup_policies.default_backup_policies.volume_backup_policies) > 0 ? var.storage_volumes : {}

  asset_id  = oci_core_volume.storage_volumes[each.key].id
  policy_id = data.oci_core_volume_backup_policies.default_backup_policies.volume_backup_policies[0].id
}
