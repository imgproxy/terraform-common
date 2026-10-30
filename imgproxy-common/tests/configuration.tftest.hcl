variables {
  tag             = "3.30.0"
  repo            = "registry.example.com/imgproxy"
  cpu             = 1
  secret_key_name = "secret"
  keys_secret     = { id = "keys", version = "1" }
  salts_secret    = { id = "salts", version = "2" }
}

# ── Image ─────────────────────────────────────────────────────────────────────

run "image_with_tag" {
  command = plan

  assert {
    condition     = output.image == "registry.example.com/imgproxy:3.30.0"
    error_message = "Image must be the repo joined to the tag with ':'"
  }
}

run "digest_uses_at_separator" {
  command = plan

  variables {
    tag = "sha256:abc123"
  }

  assert {
    condition     = output.image == "registry.example.com/imgproxy@sha256:abc123"
    error_message = "A sha256 digest must be joined with '@'"
  }
}

# ── Workers and env vars ──────────────────────────────────────────────────────

run "workers_derived_from_cpu" {
  command = plan

  variables {
    cpu = 0.75
  }

  assert {
    condition     = output.workers == 2 && output.env_vars["IMGPROXY_WORKERS"] == "2"
    error_message = "workers must be ceil(cpu * 2)"
  }
}

run "explicit_workers_win" {
  command = plan

  variables {
    workers = 5
  }

  assert {
    condition     = output.workers == 5 && output.env_vars["IMGPROXY_WORKERS"] == "5"
    error_message = "Explicit workers must override the cpu-derived value"
  }
}

run "base_env_vars" {
  command = plan

  assert {
    condition     = output.env_vars["IMGPROXY_SIGNATURE_SIZE"] == "32" && !contains(keys(output.env_vars), "IMGPROXY_TIMEOUT") && !contains(keys(output.env_vars), "OTEL_SERVICE_NAME")
    error_message = "Defaults must set signature size only; timeout and OTel stay unset"
  }
}

run "timeout_and_environment_override" {
  command = plan

  variables {
    timeout     = 30
    environment = { IMGPROXY_WORKERS = "9", FOO = "bar" }
  }

  assert {
    condition     = output.env_vars["IMGPROXY_TIMEOUT"] == "30" && output.env_vars["IMGPROXY_WORKERS"] == "9" && output.env_vars["FOO"] == "bar"
    error_message = "timeout must be set and environment must override computed values"
  }
}

run "monitoring_env_vars" {
  command = plan

  variables {
    enable_monitoring = true
  }

  assert {
    condition     = output.env_vars["IMGPROXY_OPEN_TELEMETRY_ENABLE"] == "true" && output.env_vars["OTEL_EXPORTER_OTLP_ENDPOINT"] == "http://localhost:4318" && output.env_vars["OTEL_SERVICE_NAME"] == "imgproxy"
    error_message = "Monitoring must add OTel vars with the default endpoint and service name"
  }
}

run "storage_env_var" {
  command = plan

  variables {
    storage_enabled = true
    storage_env_key = "IMGPROXY_USE_GCS"
  }

  assert {
    condition     = output.env_vars["IMGPROXY_USE_GCS"] == "true"
    error_message = "storage_enabled must set the storage env key to true"
  }
}

# ── CDN cache key ─────────────────────────────────────────────────────────────

run "no_cdn_headers_by_default" {
  command = plan

  assert {
    condition     = length(output.cdn_cache_headers) == 0 && length(output.cdn_cache_cookies) == 0
    error_message = "No cache key headers or cookies expected by default"
  }
}

run "auto_webp_adds_accept" {
  command = plan

  variables {
    environment = { IMGPROXY_AUTO_WEBP = "true" }
  }

  assert {
    condition     = output.cdn_cache_headers == ["Accept"]
    error_message = "Format detection must add Accept to the cache key"
  }
}

run "truthy_variants_recognized" {
  command = plan

  variables {
    environment = { IMGPROXY_ENFORCE_AVIF = "T" }
  }

  assert {
    condition     = output.cdn_cache_headers == ["Accept"]
    error_message = "'T' must be treated as true"
  }
}

run "falsy_value_ignored" {
  command = plan

  variables {
    environment = { IMGPROXY_AUTO_WEBP = "false" }
  }

  assert {
    condition     = length(output.cdn_cache_headers) == 0
    error_message = "'false' must not enable Accept"
  }
}

run "client_hints_add_headers" {
  command = plan

  variables {
    environment = { IMGPROXY_ENABLE_CLIENT_HINTS = "1" }
  }

  assert {
    condition     = output.cdn_cache_headers == ["Sec-Ch-Dpr", "Dpr", "Sec-Ch-Width", "Width"]
    error_message = "Client hints must add the DPR and Width headers"
  }
}

run "cache_key_headers_trimmed_and_deduped_case_insensitively" {
  command = plan

  variables {
    environment = {
      IMGPROXY_AUTO_WEBP         = "true"
      IMGPROXY_CACHE_KEY_HEADERS = " accept , X-Custom,, x-custom "
    }
  }

  assert {
    condition     = output.cdn_cache_headers == ["Accept", "X-Custom"]
    error_message = "Headers must be trimmed, empty ones dropped and case-insensitive duplicates removed (first spelling wins)"
  }
}

run "cache_key_cookies_parsed" {
  command = plan

  variables {
    environment = { IMGPROXY_CACHE_KEY_COOKIES = "a, b" }
  }

  assert {
    condition     = output.cdn_cache_cookies == tolist(["a", "b"])
    error_message = "Cookies must be split and trimmed"
  }
}

# ── Secrets ───────────────────────────────────────────────────────────────────

run "secret_key_name_secret" {
  command = plan

  assert {
    condition     = output.env_secret_vars["IMGPROXY_KEY"] == { secret = "keys", version = "1" } && output.env_secret_vars["IMGPROXY_SALT"] == { secret = "salts", version = "2" }
    error_message = "Key and salt must be emitted using the 'secret' key name"
  }
}

run "secret_key_name_id" {
  command = plan

  variables {
    secret_key_name = "id"
  }

  assert {
    condition     = output.env_secret_vars["IMGPROXY_KEY"] == { id = "keys", version = "1" }
    error_message = "Key must be emitted using the 'id' key name"
  }
}

run "optional_secrets_emitted" {
  command = plan

  variables {
    secret_secret                    = { id = "auth", version = "1" }
    trusted_signatures_secret        = { id = "trusted", version = "1" }
    source_url_encryption_key_secret = { id = "enc", version = "1" }
    pro_license_key_secret           = { id = "license", version = "1" }
  }

  assert {
    condition = alltrue([
      for k in ["IMGPROXY_SECRET", "IMGPROXY_TRUSTED_SIGNATURES", "IMGPROXY_SOURCE_URL_ENCRYPTION_KEY", "IMGPROXY_LICENSE_KEY"] :
      contains(keys(output.env_secret_vars), k)
    ])
    error_message = "All optional secrets must be emitted when provided"
  }
}

run "secrets_map_overrides_named_secret" {
  command = plan

  variables {
    secrets = { IMGPROXY_KEY = { id = "override", version = "9" } }
  }

  assert {
    condition     = output.env_secret_vars["IMGPROXY_KEY"] == { secret = "override", version = "9" }
    error_message = "var.secrets must override the dedicated secret variables"
  }
}

run "insecure_emits_no_key_or_salt" {
  command = plan

  variables {
    insecure     = true
    keys_secret  = null
    salts_secret = null
  }

  assert {
    condition     = length(output.env_secret_vars) == 0
    error_message = "insecure = true must not emit key or salt"
  }
}

run "insecure_ignores_provided_key_and_salt" {
  command = plan

  variables {
    insecure = true
  }

  assert {
    condition     = length(output.env_secret_vars) == 0
    error_message = "insecure = true must skip key and salt even when provided"
  }
}

# ── Validation failures ───────────────────────────────────────────────────────

run "missing_salt_fails" {
  command = plan

  variables {
    salts_secret = null
  }

  expect_failures = [terraform_data.checks]
}

run "missing_keys_and_salts_fail_unless_insecure" {
  command = plan

  variables {
    keys_secret  = null
    salts_secret = null
  }

  expect_failures = [terraform_data.checks]
}

run "storage_without_env_key_fails" {
  command = plan

  variables {
    storage_enabled = true
  }

  expect_failures = [terraform_data.checks]
}

run "monitoring_without_service_name_fails" {
  command = plan

  variables {
    enable_monitoring = true
    otel_service_name = null
  }

  expect_failures = [terraform_data.checks]
}

run "latest_tag_warns" {
  command = plan

  variables {
    tag = "latest"
  }

  expect_failures = [check.latest_tag]
}

run "empty_tag_rejected" {
  command = plan

  variables {
    tag = ""
  }

  expect_failures = [var.tag]
}

run "signature_size_too_large_rejected" {
  command = plan

  variables {
    signature_size = 33
  }

  expect_failures = [var.signature_size]
}

run "signature_size_zero_rejected" {
  command = plan

  variables {
    signature_size = 0
  }

  expect_failures = [var.signature_size]
}

run "zero_cpu_rejected" {
  command = plan

  variables {
    cpu = 0
  }

  expect_failures = [var.cpu]
}

run "zero_timeout_rejected" {
  command = plan

  variables {
    timeout = 0
  }

  expect_failures = [var.timeout]
}
