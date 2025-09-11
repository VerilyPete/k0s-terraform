# k0s Terraform Infrastructure

This repository contains Terraform configurations for managing k0s Kubernetes clusters across different environments.

## Project Structure

```
k0s-terraform/
├── terraform/
│   ├── environments/
│   │   ├── staging/
│   │   └── production/
│   └── modules/
│       ├── compute/
│       ├── networking/
│       ├── storage/
│       ├── iam/
│       └── k0s-environment/
├── helm-charts/
│   └── webserver/
├── scripts/
│   ├── manage-oci-routes.sh
│   └── configure-pod-cidrs.sh
├── .github/
│   └── workflows/
│       ├── terraform-apply.yml
│       ├── k0s-deploy.yml
│       ├── manage-oci-routes.yml
│       └── destroy-environment.yml
├── README.md
└── ROUTE_MANAGEMENT.md
```

## Getting Started

1. Navigate to the appropriate environment directory under `terraform/environments/`
2. Initialize Terraform: `terraform init`
3. Plan your changes: `terraform plan`
4. Apply the configuration: `terraform apply`

## Environments

- **Staging**: Development and testing environment
- **Production**: Production environment

## Modules

- **Compute**: Server and instance configurations
- **Networking**: Network infrastructure and security groups  
- **Storage**: Storage and backup configurations
- **IAM**: Identity and access management (optional)
- **k0s-environment**: Orchestrates all modules for complete k0s setup

## Scripts

- **manage-oci-routes.sh**: Automated OCI route table management for pod networking
- **configure-pod-cidrs.sh**: Helper for consistent pod CIDR assignments

## Automated Route Management

This project includes automated OCI route management for k0s pod networking, eliminating manual route table configuration. 

**Key Features:**
- Automatic route table updates during deployment
- Clean route table reset during destruction  
- Consistent pod CIDR assignment strategies
- GitHub Actions integration

**Quick Start:**
```bash
# Deploy with automatic route configuration
gh workflow run terraform-apply.yml -f environment=staging

# Manual route management
gh workflow run manage-oci-routes.yml -f environment=staging -f action=configure
```

📖 **See [ROUTE_MANAGEMENT.md](./ROUTE_MANAGEMENT.md) for complete documentation**

## CI/CD

GitHub Actions workflows are configured for:
- **terraform-apply.yml**: Infrastructure deployment with automatic route configuration
- **k0s-deploy.yml**: k0s cluster setup and pod network route management
- **manage-oci-routes.yml**: Standalone route table management
- **destroy-environment.yml**: Clean infrastructure teardown with route cleanup

## Required GitHub Secrets

For route management functionality, add these secrets to your GitHub repository:

```
# OCI Configuration
OCI_CLI_USER, OCI_CLI_TENANCY, OCI_CLI_FINGERPRINT
OCI_CLI_KEY_CONTENT, OCI_CLI_REGION, OCI_NAMESPACE
OCI_COMPARTMENT_ID, OCI_AVAILABILITY_DOMAIN
OCI_PRIVATE_SUBNET, OCI_VCN_ID, OCI_CUSTOM_IMAGE

# Route Management  
OCI_ROUTE_TABLE_STAGING       # Route table OCID for staging
OCI_ROUTE_TABLE_PRODUCTION    # Route table OCID for production
OCI_NAT_GATEWAY              # NAT gateway OCID
OCI_SERVICE_GATEWAY          # Service gateway OCID

# Access
SSH_PUBLIC_KEY, SSH_PRIVATE_KEY, TAILSCALE_AUTH_KEY
```

## Contributing

Please follow the established patterns and ensure all changes are tested in staging before applying to production.
