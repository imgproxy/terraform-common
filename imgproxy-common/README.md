# imgproxy Common Module

Internal module that provides shared imgproxy-specific configuration logic for both Azure and Google Cloud Platform modules.

## Purpose

This data-only module (creates no infrastructure resources) eliminates code duplication between the `azure/` and `cloud-run/` modules by extracting shared imgproxy configuration logic into a single source of truth.

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
- `env_secret_vars`: Secret environment variables in provider-specific format

When `enable_monitoring = true`, the module also adds the shared imgproxy OpenTelemetry environment variables and points OTLP export to `http://localhost:4318`.

## Requirements

- Terraform >= 1.5
