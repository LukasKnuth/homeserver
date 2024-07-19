variable "target_ip_v4" {
  type        = string
  description = "The IPv4 address to resolve all local Hostnames to"
}

variable "target_ip_v6" {
  type        = string
  description = "The IPv6 address to resolve all local Hostnames to"
}

variable "namespace" {
  type        = string
  description = "The Namespace to deploy everything into"
}
