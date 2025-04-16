# Cloudsmith Terraform Example

This repository provides a working example of how to use the [Cloudsmith Terraform Provider](https://registry.terraform.io/providers/cloudsmith-io/cloudsmith/latest/docs) to:

- Create and configure Cloudsmith repositories
- Define vulnerability policies
- Enable retention rules
- Set up upstream caching for PyPI, Maven, and DockerHub
- Apply geo/IP restrictions
- Manage service accounts and team access

## Requirements

- [Terraform](https://www.terraform.io/downloads.html) v0.13 or later
- A [Cloudsmith account](https://cloudsmith.com)
- Your Cloudsmith API Key
- Docker Hub credentials (for Docker upstreams)

## Setup

### 1. Clone this repo

```bash
git clone https://github.com/your-org/cloudsmith-terraform-example.git
cd cloudsmith-terraform-example

### 2. Create your terraform.tfvars file
vi terraform.tfvars

Then edit terraform.tfvars to include:

cloudsmith_api_key = "your-cloudsmith-api-key"
docker_username = "your-dockerhub-username"
docker_password = "your-dockerhub-password"
cloudsmith_org_slug = "your-org-slug"

Tip: Never commit your terraform.tfvars file if it includes secrets. Be sure it’s in .gitignore.

### 3. Initialize and apply Terraform
terraform init
terraform apply

Terraform will prompt for confirmation before applying changes.

Features Demonstrated
Two repositories (acme-prod and acme-nonprod)

Docker, PyPI, and Maven upstreams (with DockerHub credentials)

Geo-based access control (country allow/deny)

Vulnerability policies with quarantine (production only)

Retention policy for non-production repository

Example OIDC setup for GitHub Actions

Example service account and team privilege assignments

Provider Documentation
Cloudsmith Terraform Provider: https://registry.terraform.io/providers/cloudsmith-io/cloudsmith/latest/docs

License
MIT License

