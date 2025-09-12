# Fetch User Pool ID from SSM Parameter Store
data "aws_ssm_parameter" "user_pool_id" {
  name            = "/${var.env == "dev" ? "development" : var.env == "stg" ? "staging" : "production"}/ULNG/UserPoolId"
  with_decryption = true
}

# Create Resource Server and all its custom scopes
resource "aws_cognito_resource_server" "this" {
  for_each     = { for rs in var.resource_servers : rs.identifier => rs }
  user_pool_id = data.aws_ssm_parameter.user_pool_id.value
  identifier   = each.value.identifier
  name         = each.value.name

  dynamic "scope" {
    for_each = each.value.scopes
    content {
      scope_name        = scope.value
      scope_description = "Scope ${scope.value} for ${each.value.name}"
    }
  }
}
