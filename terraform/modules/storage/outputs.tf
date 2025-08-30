output "volumes" {
  description = "Storage volumes created"
  value = {
    for k, v in oci_core_volume.storage_volumes : k => {
      id           = v.id
      display_name = v.display_name
      size_gb      = v.size_in_gbs
      state        = v.state
      availability_domain = v.availability_domain
    }
  }
}

output "volume_ids" {
  description = "Volume IDs for reference"
  value = {
    for k, v in oci_core_volume.storage_volumes : k => v.id
  }
}

output "backup_policy_assignment" {
  description = "Backup policy assignment details"
  value = var.backup_policy_enabled ? {
    for k, v in oci_core_volume_backup_policy_assignment.backup_assignment : k => {
      policy_id = v.policy_id
      asset_id  = v.asset_id
    }
  } : {}
}
