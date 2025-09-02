provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {
    bucket = "terraform-state-test-cognito"
  }
}

# Read app configurations from apps.json
data "local_file" "apps_config" {
  filename = "${path.root}/../apps.json"
}

locals {
  apps = jsondecode(data.local_file.apps_config.content)

  # Create a map containing only the selected app
  selected_app_map = {
    for app in local.apps : app.name => app
    if app.name == var.app_name
  }
}

# Call module only for selected app
module "app_client" {
  source = "./modules/cognito-app-client"
  for_each = local.selected_app_map

  region                 = var.region
  application_name       = each.value.name
  env                    = var.env
  redirect_urls          = each.value.redirect_urls
  logout_urls            = each.value.logout_urls
  scopes                 = each.value.scopes
  custom_scopes          = lookup(each.value, "custom_scopes", [])
  branding_settings_path = "${path.root}/../${lookup(each.value, "branding_settings_path", "branding_setting.json")}"
  branding_assets_path   = "${path.root}/../${lookup(each.value, "branding_assets_path", "brandingassets.json")}"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "env" {
  type        = string
  description = "Environment (dev, stg, prod)"
}

variable "app_name" {
  type        = string
  description = "Application name to deploy (must exist in apps.json)"
}
