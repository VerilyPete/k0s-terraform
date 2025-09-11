#!/bin/bash
set -euo pipefail

# Pod CIDR Configuration Script for k0s Cluster
# This script helps ensure consistent pod CIDR assignments to worker nodes
#
# Usage:
#   ./configure-pod-cidrs.sh <environment>
#
# This script provides two approaches for consistent CIDR assignment:
# 1. Annotation-based assignment (recommended)
# 2. Join order control

# Function to display usage
usage() {
    cat << EOF
Usage: $0 <environment>

This script helps ensure consistent pod CIDR assignments for k0s worker nodes.

Arguments:
  environment      - Environment name (staging/production)

Approaches:
  1. Annotation-based: Manually assign CIDRs via node annotations
  2. Join order: Control the order workers join the cluster

Example:
  $0 staging

Note: Tailscale connectivity to k0s-controller-<environment> is required.
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

# Function to get current node CIDR assignments
get_current_assignments() {
    local environment="$1"
    local controller_hostname="k0s-controller-$environment"
    
    log "Getting current pod CIDR assignments from $controller_hostname..."
    
    ssh -o StrictHostKeyChecking=no "opc@$controller_hostname" \
        "/usr/local/bin/k0s kubectl get nodes -o json | jq -r '.items[] | {
            name: .metadata.name,
            pod_cidr: (.metadata.annotations[\"kube-router.io/pod-cidr\"] // \"none\"),
            ready: (.status.conditions[] | select(.type == \"Ready\") | .status)
        }'"
}

# Function to manually assign pod CIDRs
assign_pod_cidrs() {
    local environment="$1"
    local controller_hostname="k0s-controller-$environment"
    
    log "Manually assigning pod CIDRs based on worker numbers..."
    
    # Define CIDR assignments
    local -A cidr_assignments=(
        ["k0s-worker-1-$environment"]="10.244.0.0/24"
        ["k0s-worker-2-$environment"]="10.244.1.0/24"
        ["k0s-worker-3-$environment"]="10.244.2.0/24"
        ["k0s-worker-4-$environment"]="10.244.3.0/24"
    )
    
    # Get current nodes
    local nodes
    nodes=$(ssh -o StrictHostKeyChecking=no "opc@$controller_hostname" \
        "/usr/local/bin/k0s kubectl get nodes --no-headers | awk '{print \$1}'" | grep -E "worker-[0-9]+-$environment" || true)
    
    if [ -z "$nodes" ]; then
        error "No worker nodes found for environment: $environment"
        return 1
    fi
    
    # Assign CIDRs to each worker
    while IFS= read -r node; do
        if [[ -n "${cidr_assignments[$node]:-}" ]]; then
            local cidr="${cidr_assignments[$node]}"
            log "Assigning CIDR $cidr to node $node"
            
            # Annotate the node with the desired pod CIDR
            ssh -o StrictHostKeyChecking=no "opc@$controller_hostname" \
                "/usr/local/bin/k0s kubectl annotate node '$node' 'kube-router.io/pod-cidr=$cidr' --overwrite"
            
            # Force kube-router to pick up the new annotation
            log "Restarting kube-router on $node to apply new CIDR..."
            # Note: This would require SSH access to the worker node
            # In practice, you might need to restart the kube-router pod or entire node
            
        else
            log "No CIDR assignment defined for node: $node"
        fi
    done <<< "$nodes"
}

# Function to control join order
control_join_order() {
    local environment="$1"
    local controller_hostname="k0s-controller-$environment"
    
    log "Setting up controlled join order for consistent CIDR assignment..."
    
    cat << EOF

🎯 Controlled Join Order Approach:

To ensure consistent CIDR assignments, follow this join order:

1. First, join k0s-worker-1-$environment (will get 10.244.0.0/24)
2. Wait for CIDR assignment and route configuration
3. Then join k0s-worker-2-$environment (will get 10.244.1.0/24)
4. Continue in numerical order for additional workers

This approach relies on kube-router's sequential CIDR allocation behavior.

Commands to execute in order:
EOF

    # Generate join commands for each worker
    local worker_token
    worker_token=$(ssh -o StrictHostKeyChecking=no "opc@$controller_hostname" \
        "/usr/local/bin/k0s token create --role=worker --expiry=48h" 2>/dev/null || echo "ERROR: Could not generate token")
    
    if [[ "$worker_token" == "ERROR:"* ]]; then
        error "Could not generate worker token"
        return 1
    fi
    
    for i in {1..4}; do
        echo ""
        echo "# Step $i: Join worker-$i"
        echo "ssh opc@k0s-worker-$i-$environment \"echo '$worker_token' | k0s install worker --token-file /dev/stdin\""
        echo "ssh opc@k0s-worker-$i-$environment \"systemctl enable k0sworker && systemctl start k0sworker\""
        echo "# Wait and verify:"
        echo "ssh opc@$controller_hostname \"/usr/local/bin/k0s kubectl get nodes -o wide\""
        echo "# Verify CIDR assignment:"
        echo "ssh opc@$controller_hostname \"/usr/local/bin/k0s kubectl get node k0s-worker-$i-$environment -o jsonpath='{.metadata.annotations.kube-router\.io/pod-cidr}'\""
        if [ $i -lt 4 ]; then
            echo "# Wait for CIDR assignment before proceeding to next worker"
            echo "sleep 30"
        fi
    done
}

# Function to show current status
show_status() {
    local environment="$1"
    local controller_hostname="k0s-controller-$environment"
    
    log "Current cluster pod CIDR status:"
    echo ""
    
    # Show nodes and their CIDRs
    ssh -o StrictHostKeyChecking=no "opc@$controller_hostname" \
        "/usr/local/bin/k0s kubectl get nodes -o custom-columns=NAME:.metadata.name,READY:.status.conditions[?\(@.type==\"Ready\"\)].status,POD-CIDR:.metadata.annotations.kube-router\\.io/pod-cidr" 2>/dev/null || {
        error "Could not retrieve node status"
        return 1
    }
    
    echo ""
    log "Pod CIDR assignments:"
    ssh -o StrictHostKeyChecking=no "opc@$controller_hostname" \
        "/usr/local/bin/k0s kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}: {.metadata.annotations.kube-router\.io/pod-cidr}{\"\\n\"}{end}'" 2>/dev/null || {
        error "Could not retrieve CIDR assignments"
        return 1
    }
}

# Main function
main() {
    # Check arguments
    if [ $# -lt 1 ]; then
        usage
        exit 1
    fi
    
    local environment="$1"
    local command="${2:-show-status}"
    
    log "🚀 Pod CIDR Configuration for k0s cluster"
    log "Environment: $environment"
    log "Controller: k0s-controller-$environment (via Tailscale)"
    echo ""
    
    # Show current status
    show_status "$environment"
    echo ""
    
    # Provide options
    cat << EOF
🎯 Pod CIDR Configuration Options:

1. show-status     - Show current CIDR assignments
2. assign-cidrs    - Manually assign CIDRs via annotations (may require restarts)
3. join-order      - Show controlled join order instructions
4. help           - Show this help

Choose an approach based on your current cluster state:
- If workers are already joined: Use assign-cidrs (may require restarts)
- If rebuilding cluster: Use join-order for predictable assignments

Example usage:
  $0 $environment show-status
  $0 $environment assign-cidrs
  $0 $environment join-order
EOF
}

# Handle subcommands
if [ $# -ge 2 ]; then
    case "$2" in
        "show-status")
            show_status "$1"
            ;;
        "assign-cidrs")
            assign_pod_cidrs "$1"
            ;;
        "join-order")
            control_join_order "$1"
            ;;
        "help")
            usage
            ;;
        *)
            error "Unknown command: $2"
            usage
            exit 1
            ;;
    esac
else
    main "$@"
fi
