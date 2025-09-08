output "dynamic_group_id" {
  description = "ID of the dynamic group for k0s nodes"
  value       = oci_identity_dynamic_group.k0s_nodes.id
}

output "dynamic_group_name" {
  description = "Name of the dynamic group for k0s nodes"
  value       = oci_identity_dynamic_group.k0s_nodes.name
}

output "ccm_policy_id" {
  description = "ID of the CCM IAM policy"
  value       = oci_identity_policy.k0s_ccm_policy.id
}

output "ccm_policy_name" {
  description = "Name of the CCM IAM policy"
  value       = oci_identity_policy.k0s_ccm_policy.name
}
