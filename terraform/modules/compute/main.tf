
# Controller instance
resource "oci_core_instance" "controller" {
  compartment_id      = var.compartment_id
  availability_domain = var.availability_domain
  display_name        = "k8s-controller-${var.environment}"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.controller_shape_config.ocpus
    memory_in_gbs = var.controller_shape_config.memory_gb
  }

  source_details {
    source_type = "image"
    source_id   = var.image_id
  }

  create_vnic_details {
    subnet_id              = var.subnet_id
    display_name           = "k8s-controller-${var.environment}"
    assign_public_ip       = false
    skip_source_dest_check = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    HOSTNAME           = "k8s-controller-${var.environment}"
    TAILSCALE_AUTH_KEY = var.tailscale_auth_key
    user_data = base64encode(templatefile("${path.module}/cloud-init/controller.yml.tpl", {
      hostname           = "k8s-controller-${var.environment}"
      tailscale_auth_key = var.tailscale_auth_key
      environment        = var.environment
      compartment_id     = var.compartment_id
      vcn_id            = var.vcn_id
    }))
  }

  freeform_tags = {
    "Environment" = var.environment
    "Role"        = "controller"
    "ManagedBy"   = "terraform"
  }

  lifecycle {
    ignore_changes = [
      source_details[0].source_id,
    ]
  }
}

# Storage volumes are now managed by the storage module

# Generate dynamic worker configuration based on worker_count
locals {
  workers = {
    for i in range(1, var.worker_count + 1) : "worker-${i}" => {
      name           = "k8s-worker-${i}-${var.environment}"
      hostname       = "k8s-worker-${i}-${var.environment}"
      attach_storage = i == 1  # Only worker-1 gets storage for persistent volumes
    }
  }
}

# Worker instances
resource "oci_core_instance" "workers" {
  for_each = local.workers

  compartment_id      = var.compartment_id
  availability_domain = var.availability_domain
  display_name        = each.value.name
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.worker_shape_config.ocpus
    memory_in_gbs = var.worker_shape_config.memory_gb
  }

  source_details {
    source_type = "image"
    source_id   = var.image_id
  }

  create_vnic_details {
    subnet_id              = var.subnet_id
    display_name           = each.value.hostname
    assign_public_ip       = false
    skip_source_dest_check = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/cloud-init/worker.yml.tpl", {
      hostname           = each.value.hostname
      tailscale_auth_key = var.tailscale_auth_key
      environment        = var.environment
    }))
  }

  freeform_tags = {
    "Environment" = var.environment
    "Role"        = "worker"
    "Worker"      = each.key
    "ManagedBy"   = "terraform"
  }

  lifecycle {
    ignore_changes = [
      source_details[0].source_id,
    ]
  }
}

# Attach storage volume to worker-1 (volume created by storage module)
resource "oci_core_volume_attachment" "worker_storage" {
  count = length(var.storage_volume_ids) > 0 ? 1 : 0
  
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.workers["worker-1"].id
  volume_id       = var.storage_volume_ids["worker-storage"]
  display_name    = "worker-1-storage-attachment-${var.environment}"

  # Ensure the instance is running before attaching
  depends_on = [oci_core_instance.workers]
}

# Wait for all instances to be running
resource "time_sleep" "wait_for_instances" {
  depends_on = [
    oci_core_instance.controller,
    oci_core_instance.workers,
    oci_core_volume_attachment.worker_storage
  ]

  create_duration = "60s"
}

# Workers will be joined by the GitHub Actions workflow
# No provisioner needed - keep it simple and let the proven workflow handle it
