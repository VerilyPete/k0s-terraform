# Security list for k0s cluster communication
resource "oci_core_security_list" "k0s_cluster" {
  compartment_id = var.compartment_id
  vcn_id         = var.vcn_id
  display_name   = "k0s-cluster-security-list-${var.environment}"

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
    description = "k0s API server"
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
    description = "k0s controller join API"
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
    source      = var.k0s_cluster_cidr
    source_type = "CIDR_BLOCK"
    stateless   = false
  }

  ingress_security_rules {
    description = "Service network communication"
    protocol    = "all"
    source      = var.k0s_service_cidr
    source_type = "CIDR_BLOCK"
    stateless   = false
  }

  ingress_security_rules {
    description = "ICMP for pod network"
    protocol    = "1" # ICMP
    source      = var.k0s_cluster_cidr
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

# Pod networking route rules - target instances, not private IPs
data "oci_core_route_tables" "existing" {
  compartment_id = var.compartment_id
  vcn_id         = var.vcn_id
  
  filter {
    name   = "id"
    values = [var.route_table_id]
  }
}

# Create new route table with existing rules plus pod networking routes
resource "oci_core_route_table" "k0s_pod_networking" {
  compartment_id = var.compartment_id
  vcn_id         = var.vcn_id
  display_name   = "k0s-pod-networking-routes-${var.environment}"

  # Keep all existing route rules
  dynamic "route_rules" {
    for_each = length(data.oci_core_route_tables.existing.route_tables) > 0 ? data.oci_core_route_tables.existing.route_tables[0].route_rules : []
    content {
      destination       = route_rules.value.destination
      destination_type  = route_rules.value.destination_type
      network_entity_id = route_rules.value.network_entity_id
      description       = route_rules.value.description
    }
  }

  # Add pod networking routes - map each worker's pod CIDR to its instance
  dynamic "route_rules" {
    for_each = var.worker_pod_cidrs
    content {
      destination       = route_rules.value.pod_cidr
      destination_type  = "CIDR_BLOCK"
      network_entity_id = route_rules.value.instance_id
      description       = "Pod network for ${route_rules.key}"
    }
  }

  freeform_tags = {
    "Environment" = var.environment
    "ManagedBy"   = "terraform"
    "Purpose"     = "pod-networking"
  }
}

# Associate the new route table with the subnet
resource "oci_core_route_table_attachment" "k0s_subnet" {
  subnet_id      = var.subnet_id
  route_table_id = oci_core_route_table.k0s_pod_networking.id
}
