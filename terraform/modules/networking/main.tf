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

# TODO: OCI doesn't support routing to private IPs via route tables
# Error: "Local VCN routes are read only and can only be created by OCI"
# Pod networking will need to be handled at the instance level or via other means

# Commented out - route table approach doesn't work for private IP targets
# data "oci_core_route_tables" "existing" {
#   compartment_id = var.compartment_id
#   vcn_id         = var.vcn_id
#   
#   filter {
#     name   = "id"
#     values = [var.route_table_id]
#   }
# }

# locals {
#   existing_route_table = data.oci_core_route_tables.existing.route_tables[0]
# }

# resource "oci_core_route_table" "k8s_pod_networking" {
#   ...pod network route table creation...
# }

# resource "oci_core_route_table_attachment" "k8s_subnet" {
#   ...subnet association...
# }
