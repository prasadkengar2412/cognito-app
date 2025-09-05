output "client_ids" {
  description = "Map of app names to their Cognito app client IDs"
  value       = { for name, mod in module.app_client : name => mod.client_id }
}

output "secret_arns" {
  description = "Map of app names to their Secrets Manager secret ARNs"
  value       = { for name, mod in module.app_client : name => mod.secret_arn }
}
