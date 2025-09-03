# Pass through outputs from the shared k0s-environment module
output "cluster_info" {
  description = "Cluster information"
  value       = module.k0s_environment.cluster_info
}

output "connection_info" {
  description = "Connection information for the cluster"
  value       = module.k0s_environment.connection_info
}

# Additional staging-specific outputs if needed
output "environment" {
  description = "Environment name"
  value       = module.k0s_environment.environment
}

# Individual module outputs for detailed access
output "compute" {
  description = "Compute module outputs"
  value       = module.k0s_environment.compute
}

output "storage" {
  description = "Storage module outputs"
  value       = module.k0s_environment.storage
}

output "networking" {
  description = "Networking module outputs"
  value       = module.k0s_environment.networking
}