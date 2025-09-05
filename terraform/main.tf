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
  filename = "${path.module}/apps.json"
}

locals {
  apps = jsondecode(data.local_file.apps_config.content)
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
  branding_settings_path = "${path.module}/${lookup(each.value, "branding_settings_path", "branding-setting.json")}"
  branding_assets_path   = "${path.module}/${lookup(each.value, "branding_assets_path", "branding-assets.json")}"
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

output "client_ids" {
  value = { for name, mod in module.app_client : name => mod.client_id }
}

output "secret_arns" {
  value = { for name, mod in module.app_client : name => mod.secret_arn }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "env" {
  type        = string
  description = "Environment (dev, stg, prod)"
}
