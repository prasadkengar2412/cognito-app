# Fetch User Pool ID from SSM Parameter Store
data "aws_ssm_parameter" "user_pool_id" {
  name            = "/${var.env == "dev" ? "development" : var.env == "stg" ? "staging" : "production"}/ULNG/UserPoolId"
  with_decryption = true
}

# Create Resource Server for Custom Scopes (if custom_scopes are provided)
resource "aws_cognito_resource_server" "app_resource_server" {
  for_each    = length(var.custom_scopes) > 0 ? { "${var.application_name}" = var.application_name } : {}
  user_pool_id = data.aws_ssm_parameter.user_pool_id.value
  identifier   = "${var.application_name}.api"
  name         = "${var.application_name}_api"

  dynamic "scope" {
    for_each = var.custom_scopes
    content {
      scope_name        = replace(scope.value, "${var.application_name}.api/", "")
      scope_description = "Scope for ${var.application_name} ${replace(scope.value, "${var.application_name}.api/", "")}"
    }
  }
}

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
  explicit_auth_flows                  = ["ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_PASSWORD_AUTH", "ALLOW_USER_SRP_AUTH"]
  access_token_validity        = var.access_token_validity.value
  id_token_validity            = var.id_token_validity.value
  refresh_token_validity       = var.refresh_token_validity.value
  token_validity_units {
    access_token  = var.access_token_validity.unit
    id_token      = var.id_token_validity.unit
    refresh_token = var.refresh_token_validity.unit
  }
  
  depends_on = [
    aws_cognito_resource_server.app_resource_server
  ]
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
    interpreter = ["/bin/bash", "-c"]
    command = <<EOT
      set -euo pipefail

      POOL_ID="${data.aws_ssm_parameter.user_pool_id.value}"
      CLIENT_ID="${aws_cognito_user_pool_client.app_client.id}"
      REGION="${var.region}"
      SETTINGS_FILE="${var.branding_settings_path}"
      ASSETS_FILE="${var.branding_assets_path}"
      ERROR_LOG="error-${var.application_name}.log"

      echo "ℹ️ Applying branding for app ${var.application_name} (Client ID: $CLIENT_ID) in User Pool $POOL_ID"
      echo "ℹ️ Settings file: $SETTINGS_FILE"
      echo "ℹ️ Assets file: $ASSETS_FILE"
      echo "ℹ️ AWS CLI version: $(aws --version 2>>"$ERROR_LOG")"
      echo "ℹ️ jq version: $(jq --version 2>>"$ERROR_LOG")"
      echo "ℹ️ Current directory: $(pwd) 2>>"$ERROR_LOG""

      # Validate JSON files
      if ! jq . "$SETTINGS_FILE" >/dev/null 2>>"$ERROR_LOG"; then
        echo "❌ Error: Invalid JSON in settings file $SETTINGS_FILE" >>"$ERROR_LOG"
        exit 1
      fi
      if ! jq . "$ASSETS_FILE" >/dev/null 2>>"$ERROR_LOG"; then
        echo "❌ Error: Invalid JSON in assets file $ASSETS_FILE" >>"$ERROR_LOG"
        exit 1
      fi

      # Check file sizes (2 MB limit = 2097152 bytes)
      SETTINGS_SIZE=$(stat -f %z "$SETTINGS_FILE" 2>>"$ERROR_LOG" || stat -c %s "$SETTINGS_FILE" 2>>"$ERROR_LOG")
      ASSETS_SIZE=$(stat -f %z "$ASSETS_FILE" 2>>"$ERROR_LOG" || stat -c %s "$ASSETS_FILE" 2>>"$ERROR_LOG")
      if [ "$SETTINGS_SIZE" -gt 2097152 ] || [ "$ASSETS_SIZE" -gt 2097152 ]; then
        echo "❌ Error: File size exceeds 2 MB limit (Settings: $SETTINGS_SIZE bytes, Assets: $ASSETS_SIZE bytes)" >>"$ERROR_LOG"
        exit 1
      fi

      # Attempt to describe existing branding
      if BRANDING_JSON=$(aws cognito-idp describe-managed-login-branding-by-client \
        --region "$REGION" \
        --user-pool-id "$POOL_ID" \
        --client-id "$CLIENT_ID" 2>>"$ERROR_LOG"); then
          
          BRANDING_ID=$(echo "$BRANDING_JSON" | jq -r '.ManagedLoginBranding.ManagedLoginBrandingId' 2>>"$ERROR_LOG")
          if [ -z "$BRANDING_ID" ] || [ "$BRANDING_ID" = "null" ]; then
            echo "❌ Error: Failed to retrieve ManagedLoginBrandingId for client $CLIENT_ID" >>"$ERROR_LOG"
            exit 1
          fi
          echo "ℹ️ Branding exists (ID: $BRANDING_ID), updating..."
          
          if aws cognito-idp update-managed-login-branding \
            --region "$REGION" \
            --user-pool-id "$POOL_ID" \
            --managed-login-branding-id "$BRANDING_ID" \
            --settings "file://$SETTINGS_FILE" \
            --assets "file://$ASSETS_FILE" 2>>"$ERROR_LOG"; then
            echo "✅ Branding updated successfully for app ${var.application_name}"
          else
            echo "❌ Error: Failed to update branding for client $CLIENT_ID" >>"$ERROR_LOG"
            exit 1
          fi
      else
          echo "ℹ️ Branding not found, creating..."
          if aws cognito-idp create-managed-login-branding \
            --region "$REGION" \
            --user-pool-id "$POOL_ID" \
            --client-id "$CLIENT_ID" \
            --settings "file://$SETTINGS_FILE" \
            --assets "file://$ASSETS_FILE" 2>>"$ERROR_LOG"; then
            echo "✅ Branding created successfully for app ${var.application_name}"
          else
            echo "❌ Error: Failed to create branding for client $CLIENT_ID" >>"$ERROR_LOG"
            exit 1
          fi
      fi
      cat "$ERROR_LOG"
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
