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

output "storage_attachment" {
  description = "Storage volume attachment details for worker-1"
  value = length(oci_core_volume_attachment.worker_storage) > 0 ? {
    id           = oci_core_volume_attachment.worker_storage[0].id
    volume_id    = oci_core_volume_attachment.worker_storage[0].volume_id
    instance_id  = oci_core_volume_attachment.worker_storage[0].instance_id
    state        = oci_core_volume_attachment.worker_storage[0].state
  } : null
}

output "instance_ids" {
  description = "All instance IDs for reference"
  value = merge(
    { controller = oci_core_instance.controller.id },
    { for k, v in oci_core_instance.workers : k => v.id }
  )
}

output "worker_private_ips" {
  description = "List of worker node private IPs for route table configuration"
  value = [for instance in oci_core_instance.workers : instance.private_ip]
}

output "cluster_info" {
  description = "Combined cluster information for easy reference"
  value = {
    controller = {
      hostname    = oci_core_instance.controller.display_name
      private_ip  = oci_core_instance.controller.private_ip
      public_ip   = oci_core_instance.controller.public_ip
    }
    workers = [
      for instance in oci_core_instance.workers : {
        hostname    = instance.display_name
        private_ip  = instance.private_ip
        public_ip   = instance.public_ip
      }
    ]
  }
}
