
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
  name                                 = "pmg-appclient-${var.application_name}-internal-${var.env}"
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

# Apply Styling/Branding to the App Client's Hosted UI
resource "aws_cognito_user_pool_ui_customization" "styling" {
  user_pool_id = data.aws_ssm_parameter.user_pool_id.value
  client_id    = aws_cognito_user_pool_client.app_client.id
  css          = lookup(local.branding_settings, "css", "")
  image_file   = lookup(local.branding_assets, "logo_base64", null)
}

# Store in Secrets Manager
resource "aws_secretsmanager_secret" "app_secret" {
  name        = "ulng-${var.application_name}-secret-${var.env}"
  description = "App client secret for ${var.application_name} used for SSO"
}

resource "aws_secretsmanager_secret_version" "app_secret_version" {
  secret_id = aws_secretsmanager_secret.app_secret.id
  secret_string = jsonencode({
    clientid     = aws_cognito_user_pool_client.app_client.id
    clientsecret = aws_cognito_user_pool_client.app_client.client_secret
  })
}
