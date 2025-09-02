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
  apps      = jsondecode(data.local_file.apps_config.content)
  selected  = [for app in local.apps : app if app.name == var.app_name][0]
}

# Call module only for selected app
module "app_client" {
  source = "./modules/cognito-app-client"
  for_each = { for app in local.apps : app.name => app }

  region                 = var.region
  application_name       = local.selected.name
  env                    = var.env
  redirect_urls          = local.selected.redirect_urls
  logout_urls            = local.selected.logout_urls
  scopes                 = local.selected.scopes
  custom_scopes          = lookup(local.selected, "custom_scopes", [])
  branding_settings_path = "${path.root}/../${lookup(local.selected, "branding_settings_path", "branding_setting.json")}"
  branding_assets_path   = "${path.root}/../${lookup(local.selected, "branding_assets_path", "brandingassets.json")}"
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
