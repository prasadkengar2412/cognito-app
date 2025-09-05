provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {
    bucket = "terraform-state-test-cognito"
  }
}


module "app_client" {
  for_each = { for app in jsondecode(file("${path.module}/../apps.json")) : app.name => app }
  source   = "./modules/cognito-app-client"
  application_name = each.value.name
  client_type      = each.value.client_type
  env              = var.env
  region           = var.region
  redirect_urls    = each.value.redirect_urls
  logout_urls      = each.value.logout_urls
  scopes           = each.value.scopes
  custom_scopes    = lookup(each.value, "custom_scopes", [])
  access_token_validity = lookup(each.value, "access_token_validity", { value = 60, unit = "minutes" })
  id_token_validity     = lookup(each.value, "id_token_validity", { value = 60, unit = "minutes" })
  refresh_token_validity = lookup(each.value, "refresh_token_validity", { value = 30, unit = "days" })
}
