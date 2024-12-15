variable "namespace" {
  type        = string
  description = "The namespace to deploy everything into"
}

variable "cron_schedule" {
  type        = string
  description = "How often to run this check, in Cron notation"
}

variable "gotify_slack_webhook" {
  type        = string
  description = "Send problems to this Gotify Slack Incoming Webhook"
}

