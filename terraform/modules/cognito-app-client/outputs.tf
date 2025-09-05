output "client_id" {
  description = "The ID of the Cognito app client"
  value       = aws_cognito_user_pool_client.app_client.id
}

output "secret_arn" {
  description = "The ARN of the Secrets Manager secret for the app client"
  value       = aws_secretsmanager_secret.app_secret.arn
}
