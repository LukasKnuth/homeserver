variable "namespace" {
  type        = string
  description = "The namespace to deploy all resources into"
}

variable "apps_namespace" {
  type        = string
  description = "The namespace containing Apps who should be auto-discovered and added to the Dashboard"
}
