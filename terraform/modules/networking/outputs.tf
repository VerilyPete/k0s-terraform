output "security_list_id" {
  description = "Security list ID for K8s cluster"
  value       = oci_core_security_list.k8s_cluster.id
}

output "security_list_rules_summary" {
  description = "Summary of security list rules created"
  value = {
    ingress_rules = length(oci_core_security_list.k8s_cluster.ingress_security_rules)
    egress_rules  = length(oci_core_security_list.k8s_cluster.egress_security_rules)
  }
}
