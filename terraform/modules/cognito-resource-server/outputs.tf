output "resource_servers_map" {
  value = { for k, v in aws_cognito_resource_server.this : k => v.identifier }
}
output "has_resource_servers" {
  description = "Boolean indicating if resource servers were created"
  value       = length(aws_cognito_resource_server.this) > 0
}
