variable "namespace" {
  type        = string
  description = "The Namespace to deploy everything into"
}

variable "gotify_slack_webhook" {
  type        = string
  description = "Send problems to this Gotify Slack Incoming Webhook"
}
