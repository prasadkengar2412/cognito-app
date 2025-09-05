variable "application_name" {
  description = "Name of the application"
  type        = string
}

variable "client_type" {
  description = "Type of the client (e.g., internal, external)"
  type        = string
}

variable "env" {
  description = "Environment (dev, stg, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "redirect_urls" {
  description = "List of callback URLs"
  type        = list(string)
  default     = []
}

variable "logout_urls" {
  description = "List of logout URLs"
  type        = list(string)
  default     = []
}

variable "scopes" {
  description = "List of OAuth scopes"
  type        = list(string)
  default     = []
}

variable "custom_scopes" {
  description = "List of custom OAuth scopes"
  type        = list(string)
  default     = []
}

variable "access_token_validity" {
  description = "Access token validity duration and unit"
  type = object({
    value = number
    unit  = string
  })
  default = {
    value = 60
    unit  = "minutes"
  }
}

variable "id_token_validity" {
  description = "ID token validity duration and unit"
  type = object({
    value = number
    unit  = string
  })
  default = {
    value = 60
    unit  = "minutes"
  }
}

variable "refresh_token_validity" {
  description = "Refresh token validity duration and unit"
  type = object({
    value = number
    unit  = string
  })
  default = {
    value = 30
    unit  = "days"
  }
}
