provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {
    bucket = "terraform-state-test-cognito"
  }
}

# Read app configurations from apps.json in the root directory
data "local_file" "apps_config" {
  filename = "${path.root}/../apps.json"
}

locals {
  apps = jsondecode(data.local_file.apps_config.content)
}

# Global branding files (same for all apps)
# These are the files you said you stored:
# - branding-settings/branding-settings.json
# - branding-assets/branding-assets.json
locals {
  global_branding_settings = "${path.root}/../branding-settings/branding-settings.json"
  global_branding_assets   = "${path.root}/../branding-assets/branding-assets.json"
}

# Call module for each app
module "app_client" {
  for_each = { for app in local.apps : app.name => app }

  source = "./modules/cognito-app-client"

  region                 = var.region
  application_name       = each.value.name
  env                    = var.env
  client_type            = lookup(each.value, "client_type", "internal")
  redirect_urls          = each.value.redirect_urls
  logout_urls            = each.value.logout_urls
  scopes                 = each.value.scopes
  custom_scopes          = lookup(each.value, "custom_scopes", [])

  # NEW: resource server identifier/name can be provided per-app in apps.json.
  # If empty, the module will fall back to "<application_name>.api" and "<application_name>_api"
  resource_server_identifier = lookup(each.value, "resource_server_identifier", "")
  resource_server_name       = lookup(each.value, "resource_server_name", "")

  # Use global branding files for all apps — module will check file existence.
  branding_settings_path = local.global_branding_settings
  branding_assets_path   = local.global_branding_assets

  access_token_validity  = {
    value = try(each.value.access_token_validity.value, 60)
    unit  = try(each.value.access_token_validity.unit, "minutes")
  }
  id_token_validity      = {
    value = try(each.value.id_token_validity.value, 60)
    unit  = try(each.value.id_token_validity.unit, "minutes")
  }
  refresh_token_validity = {
    value = try(each.value.refresh_token_validity.value, 30)
    unit  = try(each.value.refresh_token_validity.unit, "days")
  }
}
