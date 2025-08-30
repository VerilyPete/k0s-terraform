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
│       └── storage/
├── helm-charts/
│   └── webserver/
├── .github/
│   ├── workflows/
│   │   ├── terraform-plan.yml
│   │   ├── terraform-apply.yml
│   │   ├── k8s-deploy.yml
│   │   └── destroy-environment.yml
│   └── actions/
│       └── setup-connectivity/
└── README.md
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

## CI/CD

GitHub Actions workflows are configured for:
- Terraform planning and applying
- Kubernetes deployments
- Environment destruction

## Contributing

Please follow the established patterns and ensure all changes are tested in staging before applying to production.
