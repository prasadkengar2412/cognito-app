variable "region" { type = string }
variable "env" { type = string }
variable "application_name" { type = string }
variable "client_type" { type = string }
variable "redirect_urls" { type = list(string) }
variable "logout_urls" { type = list(string) }
variable "scopes" { type = list(string) }
variable "custom_scopes" { type = list(string), default = [] }
variable "branding_settings_path" { type = string, default = "" }
variable "branding_assets_path" { type = string, default = "" }
variable "access_token_validity" { type = object({ value = number, unit = string }) }
variable "id_token_validity" { type = object({ value = number, unit = string }) }
variable "refresh_token_validity" { type = object({ value = number, unit = string }) }
