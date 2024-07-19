variable "cluster_static_ip_v4" {
  type        = string
  description = "The main IPv4, static IP through which the cluster is accessible for users"
}

variable "cluster_static_ip_v6" {
  type        = string
  description = "The main IPv6, static IP through which the cluster is accessible for users"
}

variable "s3_endpoint" {
  type        = string
  description = "Endpoint to which Litestream will replicate data via the S3 protocol"
}

variable "onepassword_vault_id" {
  type        = string
  sensitive   = true
  description = "The UUID of the 1Password Vault to read secrets from"
}

