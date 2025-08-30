output "cluster_info" {
  description = "Cluster information"
  value = {
    environment = "production"
    controller = {
      instance_id = module.compute.controller_instance.id
      private_ip  = module.compute.controller_instance.private_ip
      hostname    = "k8s-controller-production"
    }
    workers = {
      for k, v in module.compute.worker_instances : k => {
        instance_id = v.id
        private_ip  = v.private_ip
        hostname    = "k8s-${k}-production"
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

output "connection_info" {
  description = "Connection information for the cluster"
  value = {
    ssh_controller = "ssh opc@k8s-controller-production"
    kubectl_command = "sudo /usr/local/bin/k0s kubectl"
    namespace_info = {
      webserver         = "Application namespace"
      cloudflare_tunnel = "Ingress controller namespace"
      monitoring        = "Prometheus/Grafana namespace"
    }
  }
}
