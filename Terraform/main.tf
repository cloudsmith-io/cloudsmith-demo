###############################################################################
# main.tf - Example of Cloudsmith resources with Geo/IP rules via Terraform
#           Updated to remove IP-based allow/deny and only allow specific countries
###############################################################################
terraform {
  required_version = ">= 0.13"
  required_providers {
    cloudsmith = {
      source  = "cloudsmith-io/cloudsmith"
      version = "0.0.62"  # Ensure this is the latest supported version
    }
  }
}

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------
variable "cloudsmith_api_key" {
  description = "Cloudsmith API Key"
  type        = string
  sensitive   = true
}

variable "docker_username" {
  description = "Docker Hub username"
  type        = string
  sensitive   = true
}

variable "docker_password" {
  description = "Docker Hub password"
  type        = string
  sensitive   = true
}

variable "cloudsmith_org_slug" {
  description = "Slug for your Cloudsmith organization"
  type        = string
}

variable "gha_claims_owner" { 
  description = "GH user/org used for OIDC Claims to restrict access"
  type        = string
}

# Allow-list these countries (ISO 3166-1 codes) for repository access:
# IE (Ireland), GB (United Kingdom), IT (Italy), US (United States), CA (Canada)
variable "country_allow_list" {
  type    = list(string)
  default = ["IE", "GB", "IT", "US", "CA"]
}

# Deny-list is empty for this demo
variable "country_deny_list" {
  type    = list(string)
  default = []
}

provider "cloudsmith" {
  api_key = var.cloudsmith_api_key
}

# -----------------------------------------------------------------------------
# Teams
# -----------------------------------------------------------------------------
resource "cloudsmith_team" "dev_acme" {
  organization = var.cloudsmith_org_slug
  name         = "Dev-acme"
}

resource "cloudsmith_team" "ci_acme" {
  organization = var.cloudsmith_org_slug
  name         = "CI-acme"
}

# -----------------------------------------------------------------------------
# Service Account
# -----------------------------------------------------------------------------
resource "cloudsmith_service" "ci_acme_service" {
  name         = "ci_acme_service"
  organization = var.cloudsmith_org_slug

  team {
    slug = cloudsmith_team.ci_acme.slug
  }
}

# -----------------------------------------------------------------------------
# Repositories
# -----------------------------------------------------------------------------
resource "cloudsmith_repository" "acme_nonprod" {
  description = "Non-production repository for acme"
  name        = "acme-nonprod"
  namespace   = var.cloudsmith_org_slug
  slug        = "acme-nonprod"
}

resource "cloudsmith_repository" "acme_prod" {
  description    = "Production repository for acme"
  name           = "acme-prod"
  namespace      = var.cloudsmith_org_slug
  slug           = "acme-prod"
  storage_region = "us-ohio"
}

# -----------------------------------------------------------------------------
# Retention Policy for Non-Production Repository
# -----------------------------------------------------------------------------
resource "cloudsmith_repository_retention_rule" "nonprod_retention" {
  namespace                        = var.cloudsmith_org_slug
  repository                       = cloudsmith_repository.acme_nonprod.slug
  retention_enabled                = true
  retention_count_limit            = 50         # Keep max 50 packages
  retention_days_limit             = 30         # Or keep for 30 days, whichever is hit first
  retention_size_limit             = 10737418240 # 10 GB (in bytes)
  retention_group_by_name          = false
  retention_group_by_format        = false
  retention_group_by_package_type  = false
}

# -----------------------------------------------------------------------------
# Privileges
# -----------------------------------------------------------------------------
resource "cloudsmith_repository_privileges" "nonprod_privileges" {
  organization = var.cloudsmith_org_slug
  repository   = cloudsmith_repository.acme_nonprod.slug

  service {
    privilege = "Write"
    slug      = cloudsmith_service.ci_acme_service.slug
  }

  team {
    privilege = "Write"
    slug      = cloudsmith_team.dev_acme.slug
  }
}

resource "cloudsmith_repository_privileges" "prod_privileges" {
  organization = var.cloudsmith_org_slug
  repository   = cloudsmith_repository.acme_prod.slug

  service {
    privilege = "Write"
    slug      = cloudsmith_service.ci_acme_service.slug
  }

  team {
    privilege = "Read"
    slug      = cloudsmith_team.dev_acme.slug
  }
}

# -----------------------------------------------------------------------------
# Repository Upstreams
# -----------------------------------------------------------------------------
resource "cloudsmith_repository_upstream" "pypi_upstream" {
  name          = "Python Package Index"
  namespace     = var.cloudsmith_org_slug
  repository    = cloudsmith_repository.acme_nonprod.slug_perm
  upstream_type = "python"
  upstream_url  = "https://pypi.org"
  mode          = "Cache and Proxy"
}

resource "cloudsmith_repository_upstream" "maven_central" {
  name          = "Maven Central"
  namespace     = var.cloudsmith_org_slug
  repository    = cloudsmith_repository.acme_nonprod.slug_perm
  upstream_type = "maven"
  upstream_url  = "https://repo1.maven.org/maven2"
  mode          = "Cache and Proxy"
}

resource "cloudsmith_repository_upstream" "docker_hub" {
  name          = "Docker Hub"
  auth_mode     = "Username and Password"
  auth_username = var.docker_username
  auth_secret = var.docker_password
  namespace     = var.cloudsmith_org_slug
  repository    = cloudsmith_repository.acme_nonprod.slug_perm
  upstream_type = "docker"
  upstream_url  = "https://index.docker.io"
}

resource "cloudsmith_repository_upstream" "pypi_upstream_prod" {
  name          = "Python Package Index"
  namespace     = var.cloudsmith_org_slug
  repository    = cloudsmith_repository.acme_prod.slug_perm
  upstream_type = "python"
  upstream_url  = "https://pypi.org"
  mode          = "Cache and Proxy"
}

# -----------------------------------------------------------------------------
# Vulnerability Policies
# -----------------------------------------------------------------------------
resource "cloudsmith_vulnerability_policy" "nonprod_vulnerability_policy" {
  name                    = "Acme Non Production Policy"
  description             = "Vulnerability policy for the Acme non production repository"
  min_severity            = "High"
  on_violation_quarantine = false
  allow_unknown_severity  = false
  package_query_string    = "repository:${cloudsmith_repository.acme_nonprod.slug}"
  organization            = var.cloudsmith_org_slug
}

resource "cloudsmith_vulnerability_policy" "prod_vulnerability_policy" {
  name                    = "Acme Production Policy"
  description             = "Vulnerability policy for the Acme production repository"
  min_severity            = "High"
  on_violation_quarantine = true
  allow_unknown_severity  = false
  package_query_string    = "repository:${cloudsmith_repository.acme_prod.slug}"
  organization            = var.cloudsmith_org_slug
}

# -----------------------------------------------------------------------------
# OIDC Configuration (Example)
# -----------------------------------------------------------------------------
resource "cloudsmith_oidc" "my_oidc" {
  namespace        = var.cloudsmith_org_slug
  name             = "acme OIDC"
  enabled          = true
  provider_url     = "https://token.actions.githubusercontent.com"
  service_accounts = [cloudsmith_service.ci_acme_service.slug]

  claims = {
    "repository_owner" = var.gha_claims_owner 
  }
}

# -----------------------------------------------------------------------------
# Geo/IP Rules (Countries Only)
#
# We create a single resource that applies the same country-allow and country-deny
# to each repository via `for_each`. IP-based rules are removed for simplicity.
# -----------------------------------------------------------------------------
resource "cloudsmith_repository_geo_ip_rules" "geoip_for_each_repo" {
  for_each = {
    "acme-nonprod" = cloudsmith_repository.acme_nonprod
    "acme-prod"    = cloudsmith_repository.acme_prod
  }

  namespace  = each.value.namespace
  repository = each.value.slug_perm

  # No IP-based allow/deny lists
  # Only country-based rules
  country_code_allow = var.country_allow_list
  country_code_deny  = var.country_deny_list
}
