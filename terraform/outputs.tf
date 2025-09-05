output "app_client_ids" {
  value = { for k, v in module.app_client : k => v.client_id }
}

output "resource_server_details" {
  value = {
    for k, v in module.app_client :
    k => {
      name      = try(v.resource_server_name, null)
      identifier = try(v.resource_server_identifier, null)
    } if length(v.custom_scopes) > 0
  }
}
