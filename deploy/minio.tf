resource "minio_iam_user" "litestream_user" {
  name = "litestream-replication"
  tags = {
    source = "home_cgn"
    type   = "cluster"
  }
}

resource "minio_iam_service_account" "litestream_credentials" {
  target_user = minio_iam_user.litestream_user.name
}

resource "minio_iam_policy" "access_policy" {
  name = "litestream-replicate"
  # Taken from https://litestream.io/guides/s3/#restrictive-iam-policy
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:GetBucketLocation", "s3:ListBucket"],
        Resource = "arn:aws:s3:::${minio_s3_bucket.litestream_destination.bucket}"
      },
      {
        Effect = "Allow",
        Action = ["s3:PutObject", "s3:DeleteObject", "s3:GetObject"],
        Resource = [
          "arn:aws:s3:::${minio_s3_bucket.litestream_destination.bucket}/*",
          "arn:aws:s3:::${minio_s3_bucket.litestream_destination.bucket}"
        ]
      }
    ]
  })
}

resource "minio_iam_user_policy_attachment" "litestream_access" {
  user_name   = minio_iam_user.litestream_user.name
  policy_name = minio_iam_policy.access_policy.name
}

resource "minio_s3_bucket" "litestream_destination" {
  bucket = "home-cgn-litestream-replica"
}

resource "kubernetes_secret_v1" "litestream_config" {
  metadata {
    name      = "litestream-configuration"
    namespace = local.namespace
  }

  data = {
    "LITESTREAM_ACCESS_KEY_ID"     = minio_iam_service_account.litestream_credentials.access_key
    "LITESTREAM_SECRET_ACCESS_KEY" = minio_iam_service_account.litestream_credentials.secret_key
  }
}
