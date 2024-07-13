variable "namespace" {
  type        = string
  description = "The namespace to deploy all resources into"
}

variable "apps_namespace" {
  type        = string
  description = "The namespace containing Apps who should be auto-discovered and added to the Dashboard"
}

variable "onepassword_vault_id" {
  type        = string
  sensitive   = true
  description = "The 1Password vault to read user credentials from"
}
