output "resource_servers_map" {
  value = { for k, v in aws_cognito_resource_server.this : k => v.identifier }
}
