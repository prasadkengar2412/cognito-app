output "client_id" {
  value       = aws_cognito_user_pool_client.app_client.id
  description = "Cognito app client ID"
}

output "secret_arn" {
  value       = aws_secretsmanager_secret.app_secret.arn
  description = "Secrets Manager ARN"
}

output "branding_files_used" {
  value = local.apply_branding ? {
    settings = var.branding_settings_path
    assets   = var.branding_assets_path
  } : {
    settings = ""
    assets   = ""
    message  = "No branding files applied"
  }
}
