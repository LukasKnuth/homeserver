variable "name" {
  type        = string
  description = "The name of the application."
}

variable "namespace" {
  type        = string
  description = "The namespace to deploy ALL application resources into."
}

variable "image" {
  type        = string
  description = "The image descriptor to fetch and run the App"
}

variable "expose_port" {
  type        = number
  description = "The port to expose to the world for interacting with the application."
}

variable "fqdn" {
  type        = string
  description = "The FQDN the application should be avilable under"
}

variable "sqlite_path" {
  type        = string
  description = "The full path to the SQLite file which stores the application state."
}

variable "s3_url" {
  type        = string
  description = "The S3 URL to replicate the SQLite Database to."
}

variable "s3_secret_name" {
  type        = string
  description = "Name of the Secret containing S3 credentials for replication. MUST be in the same Namespace as the App!"
}

# ------------ Overridable --------------
variable "env" {
  type        = map(string)
  description = "Any ENVorinment variables"
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
