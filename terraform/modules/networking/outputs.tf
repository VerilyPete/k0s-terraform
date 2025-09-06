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

# TODO: Re-enable when pod networking solution is implemented
# output "k8s_route_table_id" {
#   description = "ID of the new K8s pod networking route table"
#   value       = oci_core_route_table.k8s_pod_networking.id
# }

# output "route_table_summary" {
#   description = "Summary of route table and rules created"
#   value = {
#     route_table_id      = oci_core_route_table.k8s_pod_networking.id
#     total_routes        = length(oci_core_route_table.k8s_pod_networking.route_rules)
#     pod_network_routes  = length(var.worker_private_ips)
#     existing_routes     = length(local.existing_route_table.route_rules)
#   }
# }
