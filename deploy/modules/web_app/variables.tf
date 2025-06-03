variable "name" {
  type        = string
  nullable    = false
  description = "The name of the application."
}

variable "namespace" {
  type        = string
  nullable    = false
  description = "The namespace to deploy ALL application resources into."
}

variable "image" {
  type        = string
  nullable    = false
  description = "The image descriptor to fetch and run the App"
}

variable "expose_port" {
  type        = number
  nullable    = false
  description = "The port to expose to the world for interacting with the application."
}

variable "fqdn" {
  type        = string
  nullable    = false
  description = "The FQDN the application should be avilable under"
}

variable "sqlite_replicate" {
  type = object({
    file_path      = string
    file_uid       = optional(number, null)
    file_gid       = optional(number, null)
    s3_bucket      = string
    s3_endpoint    = string
    s3_secret_name = string
    verify_cron    = string
  })
  nullable    = true
  default     = null
  description = "Settings for SQLite database replication via Litestream. If not specified, no replication is set up."
}

# ------------ Overridable --------------
variable "env" {
  type        = map(string)
  nullable    = false
  description = "Any ENVorinment variables"
  default     = {}
}

variable "dashboard_attributes" {
  # See https://gethomepage.dev/latest/configs/kubernetes/#automatic-service-discovery
  type        = map(string)
  nullable    = false
  description = "Metadata attributes to set on the app to customize their dashboard appearance"
  default     = {}
}

variable "readiness_get_path" {
  type        = string
  nullable    = true
  default     = null
  description = "The URL to HTTP GET for the Readiness Probe"
}

variable "liveness_get_path" {
  type        = string
  nullable    = true
  default     = null
  description = "The URL to HTTP GET for the Liveness Probe"
}

