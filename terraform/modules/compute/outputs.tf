output "controller_instance" {
  description = "Controller instance details"
  value = {
    id               = oci_core_instance.controller.id
    display_name     = oci_core_instance.controller.display_name
    private_ip       = oci_core_instance.controller.private_ip
    public_ip        = oci_core_instance.controller.public_ip
    state            = oci_core_instance.controller.state
  }
}

output "worker_instances" {
  description = "Worker instance details"
  value = {
    for k, v in oci_core_instance.workers : k => {
      id               = v.id
      display_name     = v.display_name
      private_ip       = v.private_ip
      public_ip        = v.public_ip
      state            = v.state
    }
  }
}

output "storage_volume" {
  description = "Storage volume details for worker-1"
  value = {
    id           = oci_core_volume.worker_storage.id
    display_name = oci_core_volume.worker_storage.display_name
    size_gb      = oci_core_volume.worker_storage.size_in_gbs
    state        = oci_core_volume.worker_storage.state
  }
}

output "instance_ids" {
  description = "All instance IDs for reference"
  value = merge(
    { controller = oci_core_instance.controller.id },
    { for k, v in oci_core_instance.workers : k => v.id }
  )
}
