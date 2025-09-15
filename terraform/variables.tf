variable "region" {
  type    = string
  default = "us-east-1"
}

variable "env" {
  type        = string
  description = "Environment to deploy (dev, stg, prod)"
  validation {
    condition     = contains(["dev", "stg", "prod"], var.env)
    error_message = "env must be one of dev, stg, prod"
  }
}
variable "resource_servers" {
  type = list(object({
    identifier = string
    name       = string
    scopes     = list(string)
  }))
  description = "List of resource servers and their scopes"
  default     = []
}
