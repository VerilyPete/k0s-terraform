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

output "pod_network_route_ids" {
  description = "List of pod network route rule IDs"
  value       = oci_core_route_rule.pod_network_routes[*].id
}

output "route_rules_summary" {
  description = "Summary of route rules created"
  value = {
    pod_network_routes = length(oci_core_route_rule.pod_network_routes)
  }
}
