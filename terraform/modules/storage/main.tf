# Data source for default backup policies
data "oci_core_volume_backup_policies" "default_backup_policies" {
  compartment_id = var.compartment_id

  filter {
    name   = "display_name"
    values = ["bronze"]
  }
}

# Storage volumes
resource "oci_core_volume" "storage_volumes" {
  for_each = var.storage_volumes

  compartment_id      = var.compartment_id
  availability_domain = var.availability_domain
  display_name        = "${each.value.display_name}-${var.environment}"
  size_in_gbs         = each.value.size_gb

  defined_tags = {
    "Environment" = var.environment
    "Purpose"     = each.value.description
    "ManagedBy"   = "terraform"
  }

  freeform_tags = {
    "Volume" = each.key
  }
}

# Backup policy assignment (optional)
resource "oci_core_volume_backup_policy_assignment" "backup_assignment" {
  for_each = var.backup_policy_enabled ? var.storage_volumes : {}

  asset_id  = oci_core_volume.storage_volumes[each.key].id
  policy_id = data.oci_core_volume_backup_policies.default_backup_policies.volume_backup_policies[0].id
}
