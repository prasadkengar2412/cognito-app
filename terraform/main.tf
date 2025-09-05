provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {
    bucket = "terraform-state-test-cognito"
  }
}

# -----------------------------
# 1️⃣ Load JSON configurations based on environment
# -----------------------------
data "local_file" "apps_config" {
  filename = "${path.root}/${var.env}/apps.json"
}

data "local_file" "custom_scopes_config" {
  filename = "${path.root}/custom-scope.json"
}

locals {
  apps          = jsondecode(data.local_file.apps_config.content)
  custom_scopes = jsondecode(data.local_file.custom_scopes_config.content)
}

# -----------------------------
# 2️⃣ Create Resource Servers
# -----------------------------
module "resource_servers" {
  for_each   = { for rs in local.custom_scopes : rs.identifier => rs }
  source     = "./modules/cognito-resource-server"

  env        = var.env
  identifier = each.value.identifier
  name       = each.value.name
  scopes     = each.value.scopes
}

# -----------------------------
# 3️⃣ Create App Clients
# -----------------------------
module "app_clients" {
  for_each           = { for app in local.apps : app.name => app }
  source             = "./modules/cognito-app-client"

  region             = var.region
  env                = var.env
  application_name   = each.value.name
  client_type        = lookup(each.value, "client_type", "internal")
  redirect_urls      = each.value.redirect_urls
  logout_urls        = each.value.logout_urls
  scopes             = lookup(each.value, "scopes", [])
  custom_scopes      = lookup(each.value, "custom_scopes", [])

  branding_settings_path = "${path.root}/branding-settings/branding-setting.json"
  branding_assets_path   = "${path.root}/branding-assets/branding-assets.json"

  access_token_validity = {
    value = try(each.value.access_token_validity.value, 60)
    unit  = try(each.value.access_token_validity.unit, "minutes")
  }
  id_token_validity = {
    value = try(each.value.id_token_validity.value, 60)
    unit  = try(each.value.id_token_validity.unit, "minutes")
  }
  refresh_token_validity = {
    value = try(each.value.refresh_token_validity.value, 30)
    unit  = try(each.value.refresh_token_validity.unit, "days")
  }
}


# -----------------------------
# 4️⃣ Outputs
# -----------------------------
output "client_ids" {
  value       = { for name, mod in module.app_clients : name => mod.client_id }
  description = "Map of app names to their Cognito app client IDs"
}

output "secret_arns" {
  value       = { for name, mod in module.app_clients : name => mod.secret_arn }
  description = "Map of app names to their Secrets Manager secret ARNs"
}

output "branding_files_used" {
  value       = { for name, mod in module.app_clients : name => mod.branding_files_used }
  description = "Branding files applied"
}
