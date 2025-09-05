output "client_id" {
  value = aws_cognito_user_pool_client.app_client.id
}

output "resource_server_name" {
  value = length(var.custom_scopes) > 0 ? aws_cognito_resource_server.app_resource_server[var.application_name].name : null
}

output "resource_server_identifier" {
  value = length(var.custom_scopes) > 0 ? aws_cognito_resource_server.app_resource_server[var.application_name].identifier : null
}

output "custom_scopes" {
  value = var.custom_scopes
}
