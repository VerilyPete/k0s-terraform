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

output "k8s_route_table_id" {
  description = "ID of the route table with pod networking routes"
  value       = oci_core_route_table.k0s_pod_networking.id
}

output "route_table_summary" {
  description = "Summary of route table configuration"
  value = {
    id              = oci_core_route_table.k0s_pod_networking.id
    display_name    = oci_core_route_table.k0s_pod_networking.display_name
    route_count     = length(oci_core_route_table.k0s_pod_networking.route_rules)
    existing_routes = length(data.oci_core_route_tables.existing.route_tables) > 0 ? length(data.oci_core_route_tables.existing.route_tables[0].route_rules) : 0
    pod_routes      = length(var.worker_pod_cidrs)
  }
}

output "pod_networking_routes" {
  description = "Pod networking routes that were created"
  value = {
    for k, v in var.worker_pod_cidrs : k => {
      destination = v.pod_cidr
      target      = v.instance_id
    }
  }
}
