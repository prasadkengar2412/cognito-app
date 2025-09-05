output "client_ids" {
  value = { for name, mod in module.app_client : name => mod.client_id }
}

output "secret_arns" {
  value = { for name, mod in module.app_client : name => mod.secret_arn }
}
