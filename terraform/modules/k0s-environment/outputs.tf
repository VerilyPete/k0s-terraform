# Environment identifier
output "environment" {
  description = "Environment name"
  value       = var.environment
}

# Cluster information
output "cluster_info" {
  description = "Cluster information"
  value = {
    environment = var.environment
    controller = {
      instance_id = module.compute.controller_instance.id
      private_ip  = module.compute.controller_instance.private_ip
      hostname    = "k8s-controller-${var.environment}"
    }
    workers = {
      for k, v in module.compute.worker_instances : k => {
        instance_id = v.id
        private_ip  = v.private_ip
        hostname    = "k8s-${k}-${var.environment}"
      }
    }
    storage = {
      for k, v in module.storage.volumes : k => {
        volume_id = v.id
        size_gb   = v.size_gb
      }
    }
    networking = {
      security_list_id = module.networking.security_list_id
      rules_summary    = module.networking.security_list_rules_summary
    }
  }
}

# Connection information
output "connection_info" {
  description = "Connection information for the cluster"
  value = {
    ssh_controller = "ssh opc@k8s-controller-${var.environment}"
    kubectl_command = "sudo /usr/local/bin/k0s kubectl"
    namespace_info = {
      webserver         = "Application namespace"
      cloudflare_tunnel = "Ingress controller namespace"
      monitoring        = "Prometheus/Grafana namespace"
    }
  }
}

# Individual module outputs for backward compatibility
output "compute" {
  description = "Compute module outputs"
  value = {
    controller_instance = module.compute.controller_instance
    worker_instances    = module.compute.worker_instances
    storage_attachment  = module.compute.storage_attachment
    instance_ids        = module.compute.instance_ids
    worker_private_ips  = module.compute.worker_private_ips
    cluster_info        = module.compute.cluster_info
  }
}

output "storage" {
  description = "Storage module outputs"
  value = {
    volumes                   = module.storage.volumes
    volume_ids               = module.storage.volume_ids
    backup_policy_assignment = module.storage.backup_policy_assignment
  }
}

output "networking" {
  description = "Networking module outputs"
  value = {
    security_list_id           = module.networking.security_list_id
    security_list_rules_summary = module.networking.security_list_rules_summary
    pod_network_route_ids      = module.networking.pod_network_route_ids
    route_rules_summary        = module.networking.route_rules_summary
  }
}
