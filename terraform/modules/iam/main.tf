# IAM resources for OCI Cloud Controller Manager

# Dynamic group for K8s nodes to allow instance principal authentication
resource "oci_identity_dynamic_group" "k8s_nodes" {
  compartment_id = var.tenancy_ocid
  description    = "Dynamic group for K8s nodes - allows CCM to manage networking"
  name           = "k8s-nodes-${var.environment}"
  
  # Match all instances in the compartment (could be more specific if needed)
  matching_rule = "Any {instance.compartment.id = '${var.compartment_id}'}"

  freeform_tags = {
    "Environment" = var.environment
    "ManagedBy"   = "terraform"
    "Purpose"     = "k8s-ccm"
  }
}

# IAM policy to allow CCM to manage OCI networking resources
resource "oci_identity_policy" "k8s_ccm_policy" {
  compartment_id = var.tenancy_ocid  # Policies must be in root compartment
  description    = "Policy for K8s Cloud Controller Manager to manage networking"
  name           = "k8s-ccm-policy-${var.environment}"
  
  statements = [
    # Allow managing virtual networking (route tables, security lists, etc.)
    "Allow dynamic-group ${oci_identity_dynamic_group.k8s_nodes.name} to use virtual-network-family in compartment id ${var.compartment_id}",
    
    # Allow managing load balancers if needed in the future
    "Allow dynamic-group ${oci_identity_dynamic_group.k8s_nodes.name} to manage load-balancers in compartment id ${var.compartment_id}",
    
    # Allow reading instance information
    "Allow dynamic-group ${oci_identity_dynamic_group.k8s_nodes.name} to read instance-family in compartment id ${var.compartment_id}",
    
    # Allow managing route tables specifically
    "Allow dynamic-group ${oci_identity_dynamic_group.k8s_nodes.name} to manage route-tables in compartment id ${var.compartment_id}",
  ]

  freeform_tags = {
    "Environment" = var.environment
    "ManagedBy"   = "terraform"
    "Purpose"     = "k8s-ccm"
  }
}
