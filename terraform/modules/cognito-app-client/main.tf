# Fetch User Pool ID from SSM Parameter Store
data "aws_ssm_parameter" "user_pool_id" {
  name            = "/${var.env == "dev" ? "development" : var.env == "stg" ? "staging" : "production"}/ULNG/UserPoolId"
  with_decryption = true
}

# Decide effective resource server identifier and name (use provided or fallback)
#locals {
#  effective_resource_server_identifier = var.resource_server_identifier != "" ? var.resource_server_identifier : "${var.application_name}.api"
 # effective_resource_server_name       = var.resource_server_name != "" ? var.resource_server_name : "${var.application_name}_api"
#}

# Create Resource Server for Custom Scopes (if custom_scopes are provided)
#resource "aws_cognito_resource_server" "app_resource_server" {
#  for_each     = length(var.custom_scopes) > 0 ? { "${var.application_name}" = var.application_name } : {}
#  user_pool_id = data.aws_ssm_parameter.user_pool_id.value
#  identifier   = local.effective_resource_server_identifier
 # name         = local.effective_resource_server_name

#  dynamic "scope" {
#    for_each = var.custom_scopes
#    content {
#      # If scope looks like "<identifier>/read", strip prefix. Otherwise, keep as-is.
#      scope_name        = replace(scope.value, "${local.effective_resource_server_identifier}/", "")
#      scope_description = "Scope for ${var.application_name} ${replace(scope.value, "${local.effective_resource_server_identifier}/", "")}"
#    }
#  }
#}

# Create App Client in existing User Pool
resource "aws_cognito_user_pool_client" "app_client" {
  name                                 = "ulng-appclient-${var.application_name}-${var.client_type}-${var.env}"
  user_pool_id                         = data.aws_ssm_parameter.user_pool_id.value
  generate_secret                      = true
  callback_urls                        = var.redirect_urls
  logout_urls                          = var.logout_urls
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = concat(var.scopes, var.custom_scopes)
  supported_identity_providers         = ["COGNITO"]
  explicit_auth_flows                  = ["ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_AUTH", "ALLOW_USER_SRP_AUTH"]

  access_token_validity        = var.access_token_validity.value
  id_token_validity            = var.id_token_validity.value
  refresh_token_validity       = var.refresh_token_validity.value

  token_validity_units {
    access_token  = var.access_token_validity.unit
    id_token      = var.id_token_validity.unit
    refresh_token = var.refresh_token_validity.unit
  }

}

# Read Branding Files only if paths are provided and files exist
locals {
  apply_branding = var.branding_settings_path != "" && var.branding_assets_path != "" ? fileexists(var.branding_settings_path) && fileexists(var.branding_assets_path) : false
}

data "local_file" "branding_settings" {
  count    = local.apply_branding ? 1 : 0
  filename = var.branding_settings_path
}

data "local_file" "branding_assets" {
  count    = local.apply_branding ? 1 : 0
  filename = var.branding_assets_path
}

# Ensure Terraform re-runs branding if file content changes
resource "null_resource" "branding_version" {
  count = local.apply_branding ? 1 : 0
  triggers = {
    branding_settings_hash = local.apply_branding ? sha1(data.local_file.branding_settings[0].content) : ""
    branding_assets_hash   = local.apply_branding ? sha1(data.local_file.branding_assets[0].content) : ""
  }
}

# Managed Branding (create or update) only if branding files exist
resource "null_resource" "managed_branding" {
  count = local.apply_branding ? 1 : 0

  triggers = {
    branding_settings_hash = local.apply_branding ? sha1(data.local_file.branding_settings[0].content) : ""
    branding_assets_hash   = local.apply_branding ? sha1(data.local_file.branding_assets[0].content) : ""
  }

  provisioner "local-exec" {
    command = <<EOT
      python3 ./../scripts/manage_cognito_branding.py \
        "${data.aws_ssm_parameter.user_pool_id.value}" \
        "${aws_cognito_user_pool_client.app_client.id}" \
        "${var.region}" \
        "${var.branding_settings_path}" \
        "${var.branding_assets_path}" \
        "${var.application_name}"
    EOT
  }

  depends_on = [
    aws_cognito_user_pool_client.app_client,
    null_resource.branding_version
  ]
}


# Store in Secrets Manager
resource "aws_secretsmanager_secret" "app_secret" {
  name        = "ulng-${var.application_name}-secrets-${var.client_type}-${var.env}"
  description = "App client secret for ${var.application_name} (${var.client_type}) used for SSO"
}

resource "aws_secretsmanager_secret_version" "app_secret_version" {
  secret_id = aws_secretsmanager_secret.app_secret.id
  secret_string = jsonencode({
    clientid     = aws_cognito_user_pool_client.app_client.id
    clientsecret = aws_cognito_user_pool_client.app_client.client_secret
  })
}

# Clean up secret on destroy
resource "null_resource" "secret_cleanup" {
  triggers = {
    secret_arn = aws_secretsmanager_secret.app_secret.arn
    region     = var.region
  }

  provisioner "local-exec" {
    when    = destroy
    interpreter = ["/bin/bash", "-c"]
    command = <<EOT
      set -euo pipefail
      echo "ℹ️ Permanently deleting secret ${self.triggers.secret_arn}"
      aws secretsmanager delete-secret \
        --region "${self.triggers.region}" \
        --secret-id "${self.triggers.secret_arn}" \
        --force-delete-without-recovery 2>secret_cleanup_error.log || echo "Secret already deleted or not found"
      cat secret_cleanup_error.log
    EOT
  }

  depends_on = [aws_secretsmanager_secret.app_secret]
}
