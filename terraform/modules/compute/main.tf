
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
    display_name           = "controller-vnic-${var.environment}"
    assign_public_ip       = false
    skip_source_dest_check = true
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/cloud-init/controller.yml.tpl", {
      hostname           = "k8s-controller-${var.environment}"
      tailscale_auth_key = var.tailscale_auth_key
      environment        = var.environment
    }))
  }

  defined_tags = {
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

# Storage volume for worker-1
resource "oci_core_volume" "worker_storage" {
  compartment_id      = var.compartment_id
  availability_domain = var.availability_domain
  display_name        = "k8s-worker-1-data-${var.environment}"
  size_in_gbs         = var.storage_size_gb

  defined_tags = {
    "Environment" = var.environment
    "Role"        = "storage"
    "ManagedBy"   = "terraform"
  }
}

# Worker instances
resource "oci_core_instance" "workers" {
  for_each = {
    "worker-1" = {
      name           = "k8s-worker-1-${var.environment}"
      hostname       = "k8s-worker-1-${var.environment}"
      attach_storage = true
    }
    "worker-2" = {
      name           = "k8s-worker-2-${var.environment}"
      hostname       = "k8s-worker-2-${var.environment}"
      attach_storage = false
    }
  }

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
    display_name           = "${each.key}-vnic-${var.environment}"
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

  defined_tags = {
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

# Attach storage volume to worker-1
resource "oci_core_volume_attachment" "worker_storage" {
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.workers["worker-1"].id
  volume_id       = oci_core_volume.worker_storage.id
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

  create_duration = "30s"
}
