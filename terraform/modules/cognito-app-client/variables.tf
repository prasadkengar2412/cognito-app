variable "region" {
  type = string
}
variable "application_name" {
  type = string
}
variable "env" {
  type = string
}
variable "redirect_urls" {
  type = list(string)
}
variable "logout_urls" {
  type = list(string)
}
variable "scopes" {
  type = list(string)
}
variable "custom_scopes" {
  type    = list(string)
  default = []
}
variable "branding_settings_path" {
  type = string
}
variable "branding_assets_path" {
  type = string
}
variable "access_token_validity" {
  type    = number
  default = 60
}
variable "id_token_validity" {
  type    = number
  default = 60
}
variable "refresh_token_validity" {
  type    = number
  default = 30
}
