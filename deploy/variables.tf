variable "cluster_static_ip" {
  type        = string
  description = "The main IP, static IP through which the cluster is accessible for users"
}

variable "s3_endpoint" {
  type        = string
  description = "Endpoint to which Litestream will replicate data via the S3 protocol"
}

