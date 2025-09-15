variable "region" {
  type = string
}

variable "env" {
  type = string
}

variable "resource_servers" {
  type = list(object({
    identifier = string
    name       = string
    scopes     = list(string)
  }))
  default     = []
  description = "List of resource servers and their scopes"
}
