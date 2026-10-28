# imgproxy Common Module

Internal module that provides shared imgproxy-specific configuration logic for both Azure and Google Cloud Platform modules.

## Purpose

This data-only module (creates no infrastructure resources) eliminates code duplication between the Azure and Cloud Run modules by extracting shared imgproxy configuration logic into a single source of truth. Its only resource is a `terraform_data` that holds validation checks and creates nothing in the cloud.

## What This Module Provides

- **Image reference construction**: Builds container image reference from tag and repository
- **Workers calculation**: Computes worker count from CPU allocation
- **Environment variables**: Merges imgproxy-specific environment variables
- **Secret variables**: Formats secret references in provider-specific format

## Usage

This module is called internally by the Azure and Cloud Run modules. It is not intended for direct use.

## Outputs

- `image`: Full container image reference
- `workers`: Computed number of workers
- `env_vars`: Merged environment variables map
- `cdn_cache_headers`: Headers for the CDN cache key, derived from imgproxy env vars (deduplicated case-insensitively)
- `cdn_cache_cookies`: Cookies for the CDN cache key, from `IMGPROXY_CACHE_KEY_COOKIES`
- `env_secret_vars`: Secret environment variables in provider-specific format (references only, not values)

When `enable_monitoring = true`, the module also adds the shared imgproxy OpenTelemetry environment variables and points OTLP export to `otel_exporter_endpoint` (default `http://localhost:4318`) under `otel_service_name` (default `imgproxy`).

`secrets` is merged last, so its entries override the dedicated `*_secret` variables.

## Validation

The module fails at plan time when:

- `insecure = false` and `keys_secret` or `salts_secret` is missing (imgproxy would otherwise run without URL signature checks)
- `storage_enabled = true` without `storage_env_key`
- `enable_monitoring = true` with a null `otel_service_name`
- `tag` is empty or `latest` (use a version or a `sha256:` digest)
- `signature_size` is outside 1-32, `cpu` is not positive, or `timeout` is not positive

## Tests

```sh
terraform init -backend=false && terraform test
```

## Requirements

- Terraform >= 1.5 (running the tests needs >= 1.6)
