output "security_list_id" {
  description = "Security list ID for k0s cluster"
  value       = oci_core_security_list.k0s_cluster.id
}

output "security_list_rules_summary" {
  description = "Summary of security list rules created"
  value = {
    ingress_rules = length(oci_core_security_list.k0s_cluster.ingress_security_rules)
    egress_rules  = length(oci_core_security_list.k0s_cluster.egress_security_rules)
  }
}

# Route table outputs removed - OCI doesn't support instance-targeted routes
# Pod networking will need to be handled via:
# 1. Manual OCI Console route configuration
# 2. Instance-level routing scripts
# 3. Overlay CNI plugins
