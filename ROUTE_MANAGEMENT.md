# OCI Route Management for k0s Pod Networking

This documentation covers the automated OCI route management solution for k0s pod networking, eliminating the need for manual route table configuration through the OCI console.

## Overview

### Problem Statement
- k0s uses kube-router for pod networking with CIDR `10.244.0.0/16`
- Each worker node gets assigned a `/24` subnet (e.g., `10.244.0.0/24`, `10.244.1.0/24`)
- OCI route tables need rules pointing each pod CIDR to the corresponding worker node's private IP
- Previously required manual configuration through OCI console after each cluster deployment

### Solution Architecture
- **Automated Route Management**: Shell script that queries OCI and k0s to build route table rules
- **GitHub Actions Integration**: Workflows for applying and destroying route configurations
- **Consistent CIDR Assignment**: Helper tools for predictable pod CIDR allocation

## Components

### 1. Core Scripts

#### `scripts/manage-oci-routes.sh`
Main script for OCI route table management.

**Usage:**
```bash
./scripts/manage-oci-routes.sh <action> <environment> <route_table_id> <subnet_id> <nat_gateway_id> <service_gateway_id>
```

**Actions:**
- `reset` - Reset route table to base configuration (removes all pod routes)
- `configure` - Add pod network routes based on current cluster state
- `destroy` - Reset route table to base configuration (alias for reset)

**Example:**
```bash
# Configure pod routes for staging
./scripts/manage-oci-routes.sh configure staging \
  ocid1.routetable.oc1.us-chicago-1.aaaaaaaamqbwh6hcm5i7qgx6xwxzz6dl... \
  ocid1.subnet.oc1.us-chicago-1.aaaaaaaa3f3pdm6ffrhzw3a5yqs5yw2z... \
  ocid1.natgateway.oc1.us-chicago-1.aaaaaaaaxurllej6dq4cneuhqkbege76... \
  ocid1.servicegateway.oc1.us-chicago-1.aaaaaaaaog5mqnpsihd5ekmrhhfwpeo6...

# Reset route table (removes pod routes)
./scripts/manage-oci-routes.sh reset staging [same_ocids...]
```

#### `scripts/configure-pod-cidrs.sh`
Helper script for managing consistent pod CIDR assignments.

**Usage:**
```bash
./scripts/configure-pod-cidrs.sh <controller_ip> <environment> [command]
```

**Commands:**
- `show-status` - Show current CIDR assignments
- `assign-cidrs` - Manually assign CIDRs via annotations
- `join-order` - Show controlled join order instructions

## 2. GitHub Actions Workflows

### `manage-oci-routes.yml`
Standalone workflow for route management operations.

**Triggers:**
- Manual dispatch (workflow_dispatch)
- Called by other workflows (workflow_call)

**Parameters:**
- `environment` - staging or production
- `action` - configure, reset, or destroy
- `controller_ip` - (optional) for configure action

### `k0s-deploy.yml`
Comprehensive k0s deployment workflow that includes route configuration.

**Features:**
- Waits for k0s controller readiness
- Manages worker node joining
- Configures pod network routes automatically
- Verifies cluster connectivity

### Updates to Existing Workflows

#### `terraform-apply.yml`
- Now calls `k0s-deploy.yml` after successful infrastructure deployment
- Route configuration happens automatically as part of "Configure Cluster" step

#### `destroy-environment.yml`
- Calls route reset before destroying infrastructure
- Ensures clean teardown of route table rules

## 3. Infrastructure Updates

### Terraform Variables
Re-added `route_table_id` variable to staging environment:

```hcl
variable "route_table_id" {
  description = "Route table ID for the private subnet (to add pod networking routes)"
  type        = string
}
```

### Required Secrets
Add these GitHub secrets for route management:

```
OCI_ROUTE_TABLE_STAGING      # Route table OCID for staging
OCI_ROUTE_TABLE_PRODUCTION   # Route table OCID for production  
OCI_NAT_GATEWAY              # NAT gateway OCID for default route
OCI_SERVICE_GATEWAY          # Service gateway OCID for Oracle services
SSH_PRIVATE_KEY              # SSH private key for accessing nodes
```

## Usage Scenarios

### 1. Automated Deployment (Recommended)
Route management happens automatically during terraform deployment:

1. Run terraform apply workflow
2. Infrastructure gets deployed
3. k0s cluster gets configured
4. Routes are automatically configured in "Configure Cluster" step

### 2. Manual Route Management
For troubleshooting or manual operations:

```bash
# Configure routes manually
gh workflow run manage-oci-routes.yml \
  -f environment=staging \
  -f action=configure

# Reset routes (remove pod routes)
gh workflow run manage-oci-routes.yml \
  -f environment=staging \
  -f action=reset
```

### 3. Consistent CIDR Assignment

#### Option A: Controlled Join Order (Recommended for new deployments)
1. Join workers in specific order to get predictable CIDRs:
   - `k0s-worker-1-staging` → `10.244.0.0/24`
   - `k0s-worker-2-staging` → `10.244.1.0/24`

2. Use helper script for guidance:
```bash
./scripts/configure-pod-cidrs.sh 10.0.1.100 staging join-order
```

#### Option B: Manual CIDR Assignment (For existing clusters)
1. Use annotations to force specific CIDRs:
```bash
./scripts/configure-pod-cidrs.sh 10.0.1.100 staging assign-cidrs
```

2. May require worker node restarts to pick up new assignments

## Route Table Configuration

### Base Configuration
Every route table starts with these base rules:

```json
[
  {
    "destination": "0.0.0.0/0",
    "destinationType": "CIDR_BLOCK",
    "networkEntityId": "ocid1.natgateway.oc1..."
  },
  {
    "destination": "all-ord-services-in-oracle-services-network",
    "destinationType": "SERVICE_CIDR_BLOCK",
    "networkEntityId": "ocid1.servicegateway.oc1..."
  }
]
```

### Pod Network Rules
For each worker node, a rule is added:

```json
{
  "destination": "10.244.0.0/24",
  "destinationType": "CIDR_BLOCK",
  "networkEntityId": "ocid1.privateip.oc1..."
}
```

### Example Complete Configuration
```json
[
  {
    "destination": "0.0.0.0/0",
    "destinationType": "CIDR_BLOCK",
    "networkEntityId": "ocid1.natgateway.oc1.us-chicago-1.aaaaaaaaxurllej6dq4cneuhqkbege766bym5tbkpjp27msnwiawgtedrbda"
  },
  {
    "destination": "all-ord-services-in-oracle-services-network",
    "destinationType": "SERVICE_CIDR_BLOCK",
    "networkEntityId": "ocid1.servicegateway.oc1.us-chicago-1.aaaaaaaaog5mqnpsihd5ekmrhhfwpeo6t7sw2v4oddohwg3zxjtnsiu5cmoq"
  },
  {
    "destination": "10.244.0.0/24",
    "destinationType": "CIDR_BLOCK",
    "networkEntityId": "ocid1.privateip.oc1.us-chicago-1.abxxeljsvo22wwtoxv7le5l2p3aos5xrrvt7do47a6groyvkzya7h4crpeuq"
  },
  {
    "destination": "10.244.1.0/24",
    "destinationType": "CIDR_BLOCK",
    "networkEntityId": "ocid1.privateip.oc1.us-chicago-1.abxxeljscsv43sbmzi7s5w6auwod3g5nosxgkswrd34sr44l6jdvsgyqebsa"
  }
]
```

## Troubleshooting

### Common Issues

#### 1. Route Configuration Fails
```bash
# Check if controller is accessible
ssh opc@<controller_ip> "k0s kubectl get nodes"

# Verify pod CIDR assignments
./scripts/configure-pod-cidrs.sh <controller_ip> <environment> show-status

# Check OCI CLI configuration
oci network private-ip list --subnet-id <subnet_id>
```

#### 2. Inconsistent CIDR Assignments
```bash
# View current assignments
./scripts/configure-pod-cidrs.sh <controller_ip> <environment> show-status

# Force specific assignments (may require restarts)
./scripts/configure-pod-cidrs.sh <controller_ip> <environment> assign-cidrs
```

#### 3. Manual Route Verification
```bash
# Check current route table
oci network route-table get --rt-id <route_table_id>

# Manually reset if needed
./scripts/manage-oci-routes.sh reset <environment> <route_table_id> <subnet_id> <nat_gateway_id> <service_gateway_id>
```

### Debug Mode
Enable debug output in scripts:
```bash
export DEBUG=1
./scripts/manage-oci-routes.sh configure ...
```

## Dependencies

### Required Tools
- `oci` - OCI CLI tool
- `jq` - JSON processor
- `ssh` - SSH client
- `curl` - HTTP client

### GitHub Actions Environment
- OCI CLI is automatically installed and configured
- SSH keys are set up for node access
- All required secrets are available

## Security Considerations

1. **SSH Access**: Scripts require SSH access to the k0s controller
2. **OCI Permissions**: GitHub Actions service account needs route table management permissions
3. **Secrets Management**: Route table OCIDs and SSH keys are stored as GitHub secrets
4. **Network Access**: GitHub Actions runners need network access to OCI and k0s nodes

## Limitations

1. **CIDR Assignment**: kube-router assigns CIDRs dynamically; consistent assignment requires controlled join order or manual annotation
2. **SSH Dependency**: Route configuration requires SSH access to the controller node
3. **OCI API Limits**: Large clusters may hit OCI API rate limits during route updates
4. **Manual Fallback**: In case of automation failure, manual OCI console access may be needed

## Future Enhancements

1. **OCI CCM Integration**: Investigate OCI Cloud Controller Manager for native route management
2. **Webhook Automation**: Implement k8s admission webhooks for automatic CIDR assignment
3. **Monitoring**: Add monitoring for route table configuration drift
4. **Multi-Region**: Extend support for multi-region deployments
