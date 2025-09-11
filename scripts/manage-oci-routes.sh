#!/bin/bash
set -euo pipefail

# OCI Route Management Script for k0s Pod Networking
# This script manages route table rules for pod CIDR networks in OCI
#
# Usage:
#   ./manage-oci-routes.sh <action> <environment> <route_table_id> <subnet_id> <nat_gateway_id> <service_gateway_id>
#
# Actions:
#   reset     - Reset route table to base configuration (removes all pod routes)
#   configure - Add pod network routes based on current cluster state
#   destroy   - Reset route table to base configuration (alias for reset)

# Function to display usage
usage() {
    cat << EOF
Usage: $0 <action> <environment> <route_table_id> <subnet_id> <nat_gateway_id> <service_gateway_id>

Actions:
  reset     - Reset route table to base configuration (removes all pod routes)
  configure - Add pod network routes based on current cluster state
  destroy   - Reset route table to base configuration (alias for reset)

Arguments:
  environment      - Environment name (staging/production)
  route_table_id   - OCI route table OCID
  subnet_id        - OCI subnet OCID (where k0s nodes are located)
  nat_gateway_id   - OCI NAT gateway OCID for default route
  service_gateway_id - OCI service gateway OCID for Oracle services

Example:
  $0 reset staging ocid1.routetable.oc1... ocid1.subnet.oc1... ocid1.natgateway.oc1... ocid1.servicegateway.oc1...

Environment Variables (optional):
  CONTROLLER_IP    - Controller IP address (for configure action)
  TAILSCALE_PREFIX - Tailscale hostname prefix (default: determined by environment)
EOF
}

# Function to log messages with timestamp
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Function to log error messages
error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $*" >&2
}

# Function to check if required tools are available
check_dependencies() {
    local missing_tools=()
    
    if ! command -v oci >/dev/null; then
        missing_tools+=("oci")
    fi
    
    if ! command -v jq >/dev/null; then
        missing_tools+=("jq")
    fi
    
    if ! command -v ssh >/dev/null; then
        missing_tools+=("ssh")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        error "Missing required tools: ${missing_tools[*]}"
        error "Please install the missing tools and try again"
        exit 1
    fi
}

# Function to validate OCID format
validate_ocid() {
    local ocid="$1"
    local name="$2"
    
    if [ -z "$ocid" ]; then
        error "$name is empty or not provided"
        return 1
    fi
    
    if [[ ! "$ocid" =~ ^ocid1\. ]]; then
        error "$name does not appear to be a valid OCID (should start with 'ocid1.'): $ocid"
        return 1
    fi
    
    log "✅ $name validation passed: ${ocid:0:20}..."
    return 0
}

# Function to validate input parameters
validate_parameters() {
    local route_table_id="$1"
    local subnet_id="$2"
    local nat_gateway_id="$3"
    local service_gateway_id="$4"
    
    log "Validating input parameters..."
    
    local validation_failed=false
    
    if ! validate_ocid "$route_table_id" "Route Table ID"; then
        validation_failed=true
    fi
    
    if ! validate_ocid "$subnet_id" "Subnet ID"; then
        validation_failed=true
    fi
    
    if ! validate_ocid "$nat_gateway_id" "NAT Gateway ID"; then
        validation_failed=true
    fi
    
    if ! validate_ocid "$service_gateway_id" "Service Gateway ID"; then
        validation_failed=true
    fi
    
    if [ "$validation_failed" = true ]; then
        error "Parameter validation failed. Please check your GitHub secrets and ensure they contain valid OCID values."
        error "Required secrets: OCI_ROUTE_TABLE_STAGING/PRODUCTION, OCI_PRIVATE_SUBNET, OCI_NAT_GATEWAY, OCI_SERVICE_GATEWAY"
        exit 1
    fi
    
    log "✅ All parameters validated successfully"
}

# Function to reset route table to base configuration
reset_route_table() {
    local route_table_id="$1"
    local nat_gateway_id="$2"
    local service_gateway_id="$3"
    
    log "Resetting route table to base configuration..."
    log "Using NAT Gateway: $nat_gateway_id"
    log "Using Service Gateway: $service_gateway_id"
    
    # Create base route rules JSON
    local base_rules=$(cat << EOF
[
  {
    "destination": "0.0.0.0/0",
    "destinationType": "CIDR_BLOCK",
    "networkEntityId": "$nat_gateway_id"
  },
  {
    "destination": "all-ord-services-in-oracle-services-network",
    "destinationType": "SERVICE_CIDR_BLOCK",
    "networkEntityId": "$service_gateway_id"
  }
]
EOF
    )
    
    log "Generated route rules JSON:"
    echo "$base_rules" | jq '.' || echo "$base_rules"
    
    log "Updating route table with base rules..."
    if oci network route-table update \
        --rt-id "$route_table_id" \
        --route-rules "$base_rules" \
        --force; then
        log "✅ Route table reset successfully"
    else
        error "Failed to reset route table"
        return 1
    fi
}

# Function to get private IPs from subnet
get_private_ips() {
    local subnet_id="$1"
    local environment="$2"
    
    log "Querying private IPs for subnet: $subnet_id"
    
    local private_ips
    if ! private_ips=$(oci network private-ip list --subnet-id "$subnet_id" --output json); then
        error "Failed to query private IPs"
        return 1
    fi
    
    # Filter for k0s instances in this environment
    local filtered_ips
    filtered_ips=$(echo "$private_ips" | jq -r --arg env "$environment" '
        .data[] | 
        select(.["freeform-tags"].Environment == $env and 
               (.["freeform-tags"].Role == "controller" or .["freeform-tags"].Role == "worker")) |
        {
            id: .id,
            ip_address: .["ip-address"],
            hostname: .["display-name"],
            role: .["freeform-tags"].Role,
            worker: (.["freeform-tags"].Worker // null)
        }
    ')
    
    if [ -z "$filtered_ips" ]; then
        error "No k0s instances found in subnet for environment: $environment"
        return 1
    fi
    
    echo "$filtered_ips"
}

# Function to get pod CIDR assignments from k0s cluster
get_pod_cidrs() {
    local controller_ip="$1"
    local environment="$2"
    
    # Use Tailscale hostname instead of IP address for connection
    local controller_hostname="k0s-controller-$environment"
    log "Connecting to k0s controller at $controller_hostname (Tailscale) to get pod CIDR assignments..."
    
    # Try to get node information via SSH using Tailscale hostname
    local node_info
    if ! node_info=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=30 "opc@$controller_hostname" \
        "k0s kubectl get nodes -o json" 2>/dev/null); then
        error "Failed to connect to k0s controller or get node information"
        error "Make sure Tailscale connectivity is established and controller hostname is accessible: $controller_hostname"
        return 1
    fi
    
    # Extract pod CIDR information from node annotations
    local pod_cidrs
    pod_cidrs=$(echo "$node_info" | jq -r '
        .items[] | 
        select(.status.conditions[]?.type == "Ready" and .status.conditions[]?.status == "True") |
        {
            hostname: .metadata.name,
            pod_cidr: (.metadata.annotations["kube-router.io/pod-cidr"] // null)
        } |
        select(.pod_cidr != null)
    ')
    
    if [ -z "$pod_cidrs" ]; then
        error "No pod CIDR assignments found in cluster"
        return 1
    fi
    
    echo "$pod_cidrs"
}

# Function to match hostnames between OCI and k0s
match_nodes() {
    local private_ips="$1"
    local pod_cidrs="$2"
    
    log "Matching OCI private IPs with k0s pod CIDR assignments..."
    
    # Create a combined mapping
    local matched_nodes
    matched_nodes=$(echo "$private_ips" | jq -r --argjson pod_cidrs "$pod_cidrs" '
        . as $private_ip |
        $pod_cidrs | 
        select(.hostname == $private_ip.hostname) |
        {
            hostname: .hostname,
            ip_address: $private_ip.ip_address,
            private_ip_id: $private_ip.id,
            pod_cidr: .pod_cidr,
            role: $private_ip.role
        }
    ')
    
    if [ -z "$matched_nodes" ]; then
        error "Could not match any OCI instances with k0s nodes"
        return 1
    fi
    
    echo "$matched_nodes"
}

# Function to configure route table with pod network routes
configure_route_table() {
    local route_table_id="$1"
    local nat_gateway_id="$2"
    local service_gateway_id="$3"
    local matched_nodes="$4"
    
    log "Configuring route table with pod network routes..."
    
    # Start with base rules
    local base_rules='[
        {
            "destination": "0.0.0.0/0",
            "destinationType": "CIDR_BLOCK",
            "networkEntityId": "'$nat_gateway_id'"
        },
        {
            "destination": "all-ord-services-in-oracle-services-network",
            "destinationType": "SERVICE_CIDR_BLOCK",
            "networkEntityId": "'$service_gateway_id'"
        }
    ]'
    
    # Add pod network routes
    local all_routes
    all_routes=$(echo "$base_rules" | jq --argjson nodes "$matched_nodes" '
        . + (
            $nodes | 
            select(.pod_cidr != null and .private_ip_id != null) |
            {
                "destination": .pod_cidr,
                "destinationType": "CIDR_BLOCK", 
                "networkEntityId": .private_ip_id
            }
        )
    ')
    
    log "Route table configuration:"
    echo "$all_routes" | jq '.'
    
    log "Applying route table configuration..."
    if oci network route-table update \
        --rt-id "$route_table_id" \
        --route-rules "$all_routes" \
        --force; then
        log "✅ Route table configured successfully with pod network routes"
        
        # Display summary
        local route_count
        route_count=$(echo "$matched_nodes" | jq -s 'length')
        log "📊 Summary: Added $route_count pod network routes to route table"
        echo "$matched_nodes" | jq -r '"  - " + .pod_cidr + " → " + .hostname + " (" + .ip_address + ")"'
    else
        error "Failed to configure route table"
        return 1
    fi
}

# Main function
main() {
    # Check arguments
    if [ $# -lt 6 ]; then
        usage
        exit 1
    fi
    
    local action="$1"
    local environment="$2"
    local route_table_id="$3"
    local subnet_id="$4"
    local nat_gateway_id="$5"
    local service_gateway_id="$6"
    
    # Validate action
    case "$action" in
        reset|destroy|configure)
            ;;
        *)
            error "Invalid action: $action"
            usage
            exit 1
            ;;
    esac
    
    # Check dependencies
    check_dependencies
    
    # Validate parameters
    validate_parameters "$route_table_id" "$subnet_id" "$nat_gateway_id" "$service_gateway_id"
    
    log "🚀 Starting OCI route management"
    log "Action: $action"
    log "Environment: $environment"
    log "Route Table ID: $route_table_id"
    log "Subnet ID: $subnet_id"
    
    case "$action" in
        reset|destroy)
            reset_route_table "$route_table_id" "$nat_gateway_id" "$service_gateway_id"
            ;;
        configure)
            # Get controller IP from environment variable or discover it
            local controller_ip="$CONTROLLER_IP"
            if [ -z "$controller_ip" ]; then
                log "CONTROLLER_IP not provided, discovering controller..."
                local private_ips
                private_ips=$(get_private_ips "$subnet_id" "$environment")
                controller_ip=$(echo "$private_ips" | jq -r 'select(.role == "controller") | .ip_address' | head -1)
                
                if [ -z "$controller_ip" ] || [ "$controller_ip" = "null" ]; then
                    error "Could not find controller IP address"
                    exit 1
                fi
                log "Discovered controller IP: $controller_ip"
            fi
            
            # Get private IPs and pod CIDR assignments
            local private_ips pod_cidrs matched_nodes
            private_ips=$(get_private_ips "$subnet_id" "$environment")
            pod_cidrs=$(get_pod_cidrs "$controller_ip" "$environment")
            matched_nodes=$(match_nodes "$private_ips" "$pod_cidrs")
            
            # Configure the route table
            configure_route_table "$route_table_id" "$nat_gateway_id" "$service_gateway_id" "$matched_nodes"
            ;;
    esac
    
    log "✅ OCI route management completed successfully"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
