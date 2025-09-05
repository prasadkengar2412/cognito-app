output "client_id" {
  description = "The ID of the Cognito app client"
  value       = aws_cognito_user_pool_client.app_client.id
}

output "secret_arn" {
  description = "The ARN of the Secrets Manager secret for the app client"
  value       = aws_secretsmanager_secret.app_secret.arn
}

output "branding_files_used" {
  description = "Branding files used for this app client"
  value = local.apply_branding ? {
    settings = var.branding_settings_path
    assets   = var.branding_assets_path
  } : {
    settings = ""
    assets   = ""
    message  = "No branding files applied for ${var.application_name}"
  }
}
