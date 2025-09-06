# Security list for K8s cluster communication
resource "oci_core_security_list" "k8s_cluster" {
  compartment_id = var.compartment_id
  vcn_id         = var.vcn_id
  display_name   = "k8s-cluster-security-list-${var.environment}"

  # Ingress rules
  ingress_security_rules {
    description = "SSH access"
    protocol    = "6" # TCP
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = false

    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    description = "K8s API server"
    protocol    = "6" # TCP
    source      = var.private_subnet_cidr
    source_type = "CIDR_BLOCK"
    stateless   = false

    tcp_options {
      min = 6443
      max = 6443
    }
  }

  ingress_security_rules {
    description = "K8s controller join API"
    protocol    = "6" # TCP
    source      = var.private_subnet_cidr
    source_type = "CIDR_BLOCK"
    stateless   = false

    tcp_options {
      min = 9443
      max = 9443
    }
  }

  ingress_security_rules {
    description = "Kubelet API"
    protocol    = "6" # TCP
    source      = var.private_subnet_cidr
    source_type = "CIDR_BLOCK"
    stateless   = false

    tcp_options {
      min = 10250
      max = 10250
    }
  }

  ingress_security_rules {
    description = "etcd client/peer communication"
    protocol    = "6" # TCP
    source      = var.private_subnet_cidr
    source_type = "CIDR_BLOCK"
    stateless   = false

    tcp_options {
      min = 2379
      max = 2380
    }
  }

  ingress_security_rules {
    description = "Konnectivity agent"
    protocol    = "6" # TCP
    source      = var.private_subnet_cidr
    source_type = "CIDR_BLOCK"
    stateless   = false

    tcp_options {
      min = 8132
      max = 8133
    }
  }

  ingress_security_rules {
    description = "Kube-router BGP"
    protocol    = "6" # TCP
    source      = var.private_subnet_cidr
    source_type = "CIDR_BLOCK"
    stateless   = false

    tcp_options {
      min = 179
      max = 179
    }
  }

  ingress_security_rules {
    description = "Pod network communication"
    protocol    = "all"
    source      = var.k8s_cluster_cidr
    source_type = "CIDR_BLOCK"
    stateless   = false
  }

  ingress_security_rules {
    description = "Service network communication"
    protocol    = "all"
    source      = var.k8s_service_cidr
    source_type = "CIDR_BLOCK"
    stateless   = false
  }

  ingress_security_rules {
    description = "ICMP for pod network"
    protocol    = "1" # ICMP
    source      = var.k8s_cluster_cidr
    source_type = "CIDR_BLOCK"
    stateless   = false
  }

  ingress_security_rules {
    description = "NodePort services (monitoring access)"
    protocol    = "6" # TCP
    source      = var.private_subnet_cidr
    source_type = "CIDR_BLOCK"
    stateless   = false

    tcp_options {
      min = 30000
      max = 32767
    }
  }

  # Egress rules
  egress_security_rules {
    description      = "All outbound traffic"
    protocol         = "all"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    stateless        = false
  }

  freeform_tags = {
    "Environment" = var.environment
    "ManagedBy"   = "terraform"
  }
}

# Read existing route table to preserve current routes
data "oci_core_route_tables" "existing" {
  compartment_id = var.compartment_id
  vcn_id         = var.vcn_id
  
  filter {
    name   = "id"
    values = [var.route_table_id]
  }
}

# Get the first (and only) route table from the filtered list
locals {
  existing_route_table = data.oci_core_route_tables.existing.route_tables[0]
}

# Create new route table with existing routes + pod network routes
resource "oci_core_route_table" "k8s_pod_networking" {
  compartment_id = var.compartment_id
  vcn_id         = var.vcn_id
  display_name   = "k8s-pod-network-routes-${var.environment}"

  # Preserve existing routes from the original route table
  dynamic "route_rules" {
    for_each = local.existing_route_table.route_rules
    content {
      destination       = route_rules.value.destination
      destination_type  = route_rules.value.destination_type
      network_entity_id = route_rules.value.network_entity_id
      description       = route_rules.value.description
    }
  }

  # Add pod network routes for each worker
  dynamic "route_rules" {
    for_each = { for idx, ip in var.worker_private_ips : idx => ip }
    content {
      destination       = "10.244.${route_rules.key}.0/24"
      destination_type  = "CIDR_BLOCK"
      network_entity_id = route_rules.value
      description       = "Pod network for worker-${route_rules.key + 1} - ${var.environment}"
    }
  }

  freeform_tags = {
    "Environment" = var.environment
    "ManagedBy"   = "terraform"
    "Purpose"     = "k8s-pod-networking"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Update subnet to use our new route table
resource "oci_core_route_table_attachment" "k8s_subnet" {
  subnet_id      = var.subnet_id
  route_table_id = oci_core_route_table.k8s_pod_networking.id

  lifecycle {
    create_before_destroy = true
  }
}
