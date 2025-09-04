
# Fetch User Pool ID from SSM Parameter Store
data "aws_ssm_parameter" "user_pool_id" {
  name            = "/${var.env == "dev" ? "development" : var.env == "stg" ? "staging" : "production"}/ULNG/UserPoolId"
  with_decryption = true
}

# Create Resource Server for Custom Scopes (if custom_scopes are provided)
resource "aws_cognito_resource_server" "app_resource_server" {
  for_each    = length(var.custom_scopes) > 0 ? { "${var.application_name}" = var.application_name } : {}
  user_pool_id = data.aws_ssm_parameter.user_pool_id.value
  identifier   = "${var.application_name}.api"  # e.g., app1.api
  name         = "${var.application_name}_api"

  dynamic "scope" {
    for_each = var.custom_scopes
    content {
      scope_name        = replace(scope.value, "${var.application_name}.api/", "")  # e.g., read from app1.api/read
      scope_description = "Scope for ${var.application_name} ${replace(scope.value, "${var.application_name}.api/", "")}"
    }
  }
}


# Create App Client in existing User Pool
resource "aws_cognito_user_pool_client" "app_client" {
  name                                 = "ulng-appclient-${var.application_name}-internal-${var.env}"
  user_pool_id                         = data.aws_ssm_parameter.user_pool_id.value
  generate_secret                      = true
  callback_urls                        = var.redirect_urls
  logout_urls                          = var.logout_urls
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = concat(var.scopes, var.custom_scopes)
  supported_identity_providers         = ["COGNITO"]
  explicit_auth_flows                  = ["ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_SRP_AUTH"]
  
  depends_on = [
      aws_cognito_resource_server.app_resource_server
  ]
}

# Read Branding Files
data "local_file" "branding_settings" {
  filename = var.branding_settings_path
}

data "local_file" "branding_assets" {
  filename = var.branding_assets_path
}

locals {
  branding_settings = jsondecode(data.local_file.branding_settings.content)
  branding_assets   = jsondecode(data.local_file.branding_assets.content)
}

resource "null_resource" "managed_branding" {
  triggers = {
    branding_settings_hash = sha1(data.local_file.branding_settings.content)
    branding_assets_hash   = sha1(data.local_file.branding_assets.content)
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = <<EOT
      set -euo pipefail

      POOL_ID="${data.aws_ssm_parameter.user_pool_id.value}"
      CLIENT_ID="${aws_cognito_user_pool_client.app_client.id}"
      SETTINGS_FILE="${var.branding_settings_path}"
      ASSETS_FILE="${var.branding_assets_path}"

      echo "ℹ️ Checking if branding exists for client $CLIENT_ID"

      if aws cognito-idp describe-managed-login-branding \
          --user-pool-id "$POOL_ID" \
          --client-id "$CLIENT_ID" >/dev/null 2>&1; then
        echo "ℹ️ Branding exists, updating..."
        aws cognito-idp update-managed-login-branding \
          --user-pool-id "$POOL_ID" \
          --client-id "$CLIENT_ID" \
          --settings "file://$SETTINGS_FILE" \
          --assets "file://$ASSETS_FILE"
      else
        echo "ℹ️ Branding not found, creating..."
        aws cognito-idp create-managed-login-branding \
          --user-pool-id "$POOL_ID" \
          --client-id "$CLIENT_ID" \
          --settings "file://$SETTINGS_FILE" \
          --assets "file://$ASSETS_FILE"
      fi
    EOT
  }

  depends_on = [
    aws_cognito_user_pool_client.app_client,  # ensures branding runs after client creation
    null_resource.branding_version            # ensures re-run when files change
  ]
}
# Store in Secrets Manager
resource "aws_secretsmanager_secret" "app_secret" {
  name        = "ulng-${var.application_name}-secrets-${var.env}"
  description = "App client secret for ${var.application_name} used for SSO"
}

resource "aws_secretsmanager_secret_version" "app_secret_version" {
  secret_id = aws_secretsmanager_secret.app_secret.id
  secret_string = jsonencode({
    clientid     = aws_cognito_user_pool_client.app_client.id
    clientsecret = aws_cognito_user_pool_client.app_client.client_secret
  })
}
