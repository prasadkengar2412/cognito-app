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
}
