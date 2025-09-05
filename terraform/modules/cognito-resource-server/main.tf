data "aws_ssm_parameter" "user_pool_id" {
  name            = "/${var.env == "dev" ? "development" : var.env == "stg" ? "staging" : "production"}/ULNG/UserPoolId"
  with_decryption = true
}

resource "aws_cognito_resource_server" "this" {
  user_pool_id = data.aws_ssm_parameter.user_pool_id.value
  identifier   = var.identifier
  name         = var.name

  dynamic "scope" {
    for_each = var.scopes
    content {
      scope_name        = scope.value
      scope_description = "Scope for ${var.name} - ${scope.value}"
    }
  }
}

output "scopes" {
  value = [for s in var.scopes : "${var.identifier}/${s}"]
}

output "identifier" {
  value = var.identifier
}

output "name" {
  value = var.name
}
