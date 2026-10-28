locals {
  # Image reference construction
  ref  = startswith(var.tag, "sha256:") ? "@${var.tag}" : ":${var.tag}"
  repo = var.repo != null ? var.repo : (var.pro ? var.pro_repo_default : var.community_repo_default)
  image = "${local.repo}${local.ref}"

  # Workers calculation (must be integer for IMGPROXY_WORKERS env var)
  workers = var.workers != null ? var.workers : ceil(var.cpu * 2)

  # Environment variables merge
  env_vars = merge(
    { IMGPROXY_SIGNATURE_SIZE = tostring(var.signature_size) },
    { IMGPROXY_WORKERS = tostring(local.workers) },
    var.timeout != null ? { IMGPROXY_TIMEOUT = tostring(var.timeout) } : {},
    var.enable_monitoring ? {
      IMGPROXY_OPEN_TELEMETRY_ENABLE         = "true"
      IMGPROXY_OPEN_TELEMETRY_ENABLE_METRICS = "true"
      IMGPROXY_OPEN_TELEMETRY_ENABLE_LOGS    = "false"
      OTEL_EXPORTER_OTLP_ENDPOINT            = "http://localhost:4318"
      OTEL_EXPORTER_OTLP_PROTOCOL            = "http/protobuf"
      OTEL_SERVICE_NAME                      = var.otel_service_name
    } : {},
    var.storage_enabled ? { (var.storage_env_key) = "true" } : {},
    var.environment,
  )

  # CDN cache key derivation from imgproxy env vars
  _truthy = toset(["1", "t", "T", "TRUE", "true", "True"])

  _cache_key_headers_raw = lookup(var.environment, "IMGPROXY_CACHE_KEY_HEADERS", "")
  _cache_key_headers     = local._cache_key_headers_raw != "" ? compact([for h in split(",", local._cache_key_headers_raw) : trimspace(h)]) : []

  _cache_key_cookies_raw = lookup(var.environment, "IMGPROXY_CACHE_KEY_COOKIES", "")
  _cache_key_cookies     = local._cache_key_cookies_raw != "" ? compact([for c in split(",", local._cache_key_cookies_raw) : trimspace(c)]) : []

  _format_detect_keys = ["IMGPROXY_AUTO_WEBP", "IMGPROXY_AUTO_AVIF", "IMGPROXY_AUTO_JXL",
    "IMGPROXY_ENFORCE_WEBP", "IMGPROXY_ENFORCE_AVIF", "IMGPROXY_ENFORCE_JXL"]
  _cdn_include_accept       = anytrue([for k in local._format_detect_keys : contains(local._truthy, lookup(var.environment, k, ""))])
  _cdn_include_client_hints = contains(local._truthy, lookup(var.environment, "IMGPROXY_ENABLE_CLIENT_HINTS", ""))

  cdn_cache_headers = distinct(compact(concat(
    local._cdn_include_accept ? ["Accept"] : [],
    local._cdn_include_client_hints ? ["Sec-Ch-Dpr", "Dpr", "Sec-Ch-Width", "Width"] : [],
    local._cache_key_headers,
  )))
  cdn_cache_cookies = local._cache_key_cookies

  # Secret variables (parameterized key name: "id" vs "secret")
  env_secret_vars = merge(
    var.insecure ? {} : (
      var.keys_secret != null && var.salts_secret != null ? {
        IMGPROXY_KEY  = { (var.secret_key_name) = var.keys_secret.id, version = var.keys_secret.version }
        IMGPROXY_SALT = { (var.secret_key_name) = var.salts_secret.id, version = var.salts_secret.version }
      } : {}
    ),
    var.secret_secret != null ? {
      IMGPROXY_SECRET = { (var.secret_key_name) = var.secret_secret.id, version = var.secret_secret.version }
    } : {},
    var.trusted_signatures_secret != null ? {
      IMGPROXY_TRUSTED_SIGNATURES = { (var.secret_key_name) = var.trusted_signatures_secret.id, version = var.trusted_signatures_secret.version }
    } : {},
    var.source_url_encryption_key_secret != null ? {
      IMGPROXY_SOURCE_URL_ENCRYPTION_KEY = { (var.secret_key_name) = var.source_url_encryption_key_secret.id, version = var.source_url_encryption_key_secret.version }
    } : {},
    var.pro_license_key_secret != null ? {
      IMGPROXY_LICENSE_KEY = { (var.secret_key_name) = var.pro_license_key_secret.id, version = var.pro_license_key_secret.version }
    } : {},
    { for k, v in var.secrets : k => { (var.secret_key_name) = v.id, version = v.version } }
  )
}
