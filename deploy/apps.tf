resource "kubernetes_namespace" "apps" {
  metadata {
    name = "apps"
  }
}

module "dashboard" {
  source               = "./dashboard"
  namespace            = kubernetes_namespace.apps.metadata.0.name
  apps_namespace       = kubernetes_namespace.apps.metadata.0.name
  onepassword_vault_id = var.onepassword_vault_id
}

module "testapp" {
  source      = "./modules/stateful_web_app"
  name        = "wallabag"
  namespace   = kubernetes_namespace.apps.metadata.0.name
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
  namespace = kubernetes_namespace.apps.metadata.0.name
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

resource "gotify_client" "dashboard" {
  name = "Dashboard Widget"
}

module "gotify" {
  source    = "./modules/stateful_web_app"
  name      = "gotify"
  namespace = kubernetes_namespace.apps.metadata.0.name
  image     = "ghcr.io/gotify/server-arm64:2.5.0"
  env = {
    "GOTIFY_REGISTRATION"               = true
    "TZ"                                = "Europe/Berlin"
    "GOTIFY_SERVER_SSL_ENABLED"         = false
    "GOTIFY_SERVER_SSL_REDIRECTTOHTTPS" = false
    "GOTIFY_DATABASE_DIALECT"           = "sqlite3"
    "GOTIFY_DATABASE_CONNECTION"        = "data/gotify.db"
  }
  dashboard_attributes = {
    "gethomepage.dev/group"         = "Monitoring"
    "gethomepage.dev/widget.type"   = "gotify"
    "gethomepage.dev/widget.fields" = "[\"messages\"]"
    # NOTE change this if either name, namespace or expose_port change!
    "gethomepage.dev/widget.url" = "http://gotify.apps.svc.cluster.local"
    "gethomepage.dev/widget.key" = gotify_client.dashboard.token
  }
  expose_port        = 80
  readiness_get_path = "/health"
  liveness_get_path  = "/health"
  fqdn               = "gotify.rpi"
  sqlite_path        = "/app/data/gotify.db"
  s3_secret_name     = kubernetes_secret_v1.litestream_config.metadata.0.name
  s3_bucket          = minio_s3_bucket.litestream_destination.bucket
  s3_endpoint        = var.s3_endpoint
}

module "wiki" {
  source    = "./modules/stateful_web_app"
  name      = "silicon"
  namespace = kubernetes_namespace.apps.metadata.0.name
  image     = "bityard/silicon:0.1.2"
  dashboard_attributes = {
    "gethomepage.dev/name" = "Wiki"
  }
  expose_port     = 5000
  fqdn            = "wiki.rpi"
  sqlite_path     = "/home/silicon/instance/silicon.sqlite"
  sqlite_file_uid = 5000 # silicon
  sqlite_file_gid = 5000 # silicon
  s3_secret_name  = kubernetes_secret_v1.litestream_config.metadata.0.name
  s3_bucket       = minio_s3_bucket.litestream_destination.bucket
  s3_endpoint     = var.s3_endpoint
}

module "watchlist" {
  source    = "./modules/stateful_web_app"
  name      = "watcharr"
  namespace = kubernetes_namespace.apps.metadata.0.name
  image     = "ghcr.io/sbondco/watcharr:v1.41.0"
  dashboard_attributes = {
    "gethomepage.dev/description" = "Watchlist"
  }
  expose_port    = 3080
  fqdn           = "watchlist.rpi"
  sqlite_path    = "/data/watcharr.db"
  s3_secret_name = kubernetes_secret_v1.litestream_config.metadata.0.name
  s3_bucket      = minio_s3_bucket.litestream_destination.bucket
  s3_endpoint    = var.s3_endpoint
}

module "notes" {
  source = "./modules/stateful_web_app"
  # NOTE: Can't just be memos, see https://github.com/usememos/memos/issues/1782#issuecomment-1576627426
  name      = "memos-notes"
  namespace = kubernetes_namespace.apps.metadata.0.name
  image     = "ghcr.io/usememos/memos:0.22.4"
  dashboard_attributes = {
    "gethomepage.dev/name" = "Notes"
  }
  env = {
    "MEMOS_PUBLIC" = true
  }
  expose_port    = 5230
  fqdn           = "notes.rpi"
  sqlite_path    = "/var/opt/memos/memos_prod.db"
  s3_secret_name = kubernetes_secret_v1.litestream_config.metadata.0.name
  s3_bucket      = minio_s3_bucket.litestream_destination.bucket
  s3_endpoint    = var.s3_endpoint
}

