provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {
    bucket         = "terraform-state-test-cognito"  
  }
}

# Read app configurations from apps.json
data "local_file" "apps_config" {
  filename = "./apps.json"
}

locals {
  apps = jsondecode(data.local_file.apps_config.content)
}

# Call module for each app
module "app_clients" {
  source   = "./modules/cognito-app-client"
  for_each = { for app in local.apps : app.name => app }

  region                 = var.region
  application_name       = each.value.name
  env                    = var.env
  redirect_urls          = each.value.redirect_urls
  logout_urls            = each.value.logout_urls
  scopes                 = each.value.scopes
  custom_scopes          = lookup(each.value, "custom_scopes", [])
  branding_settings_path = lookup(each.value, "branding_settings_path", "./branding-setting.json")
  branding_assets_path   = lookup(each.value, "branding_assets_path", "./brandingassets.json")
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "env" {
  type        = string
  description = "Environment (dev, stg, prod)"
}
