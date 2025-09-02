output "client_id" {
  value = aws_cognito_user_pool_client.app_client.id
}
output "secret_arn" {
  value = aws_secretsmanager_secret.app_secret.arn
}
