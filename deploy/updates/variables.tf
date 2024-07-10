variable "namespace" {
  type        = string
  description = "The namespace to deploy everything into"
}

variable "observe_namespaces" {
  type        = list(string)
  description = "The namespaces to monitor"
}

variable "cron_schedule" {
  type        = string
  description = "How often to run this check, in Cron notation"
}

variable "gotify_endpoint" {
  type        = string
  description = "Gotify Service Endpoint to publish notifications under"
}

variable "gotify_token" {
  type        = string
  description = "Gotify Application Token to publich notifications with"
}
