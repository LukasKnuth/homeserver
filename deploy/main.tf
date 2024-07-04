locals {
  namespace = "apps"
}

resource "kubernetes_namespace" "apps" {
  metadata {
    name = local.namespace
  }
}

module "testapp" {
  source      = "./modules/stateful_web_app"
  name        = "wallabag"
  namespace   = local.namespace
  image       = "wallabag/wallabag:2.6.9"
  expose_port = 80
  env = {
    "SYMFONY__ENV__DOMAIN_NAME"     = "http://wallabag.rpi"
    "SYMFONY__ENV__DATABASE_DRIVER" = "pdo_sqlite"
  }
  fqdn            = "wallabag.rpi"
  sqlite_path     = "/var/www/wallabag/data/db/wallabag.sqlite"
  sqlite_file_uid = 65534 # user "nobody"
  sqlite_file_gid = 65534 # group "nobody"
  s3_secret_name  = kubernetes_secret_v1.litestream_config.metadata.0.name
  s3_bucket       = minio_s3_bucket.litestream_destination.bucket
  s3_endpoint     = var.s3_endpoint
}

module "nocodb" {
  source    = "./modules/stateful_web_app"
  name      = "nocodb"
  namespace = local.namespace
  image     = "nocodb/nocodb:0.251.1"
  env = {
    "NC_DISABLE_ERR_REPORT" = "true"
    "NC_DISABLE_TELE"       = "true"
  }
  expose_port        = 8080
  liveness_get_path  = "/api/v1/health"
  readiness_get_path = "/api/v1/health"
  fqdn               = "nocodb.rpi"
  sqlite_path        = "/usr/app/data/noco.db"
  s3_secret_name     = kubernetes_secret_v1.litestream_config.metadata.0.name
  s3_bucket          = minio_s3_bucket.litestream_destination.bucket
  s3_endpoint        = var.s3_endpoint
}

