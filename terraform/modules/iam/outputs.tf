output "dynamic_group_id" {
  description = "ID of the dynamic group for K8s nodes"
  value       = oci_identity_dynamic_group.k8s_nodes.id
}

output "dynamic_group_name" {
  description = "Name of the dynamic group for K8s nodes"
  value       = oci_identity_dynamic_group.k8s_nodes.name
}

output "ccm_policy_id" {
  description = "ID of the CCM IAM policy"
  value       = oci_identity_policy.k8s_ccm_policy.id
}

output "ccm_policy_name" {
  description = "Name of the CCM IAM policy"
  value       = oci_identity_policy.k8s_ccm_policy.name
}
