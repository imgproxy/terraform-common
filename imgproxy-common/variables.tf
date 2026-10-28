# Image Configuration
variable "tag" {
  type        = string
  description = "imgproxy image tag (version)."
}

variable "repo" {
  type        = string
  description = "Custom container repository to use. When set, overrides the repository constructed from 'pro'."
}

variable "pro" {
  type        = bool
  description = "Use imgproxy Pro version."
}

variable "pro_repo_default" {
  type        = string
  description = "Default repository for imgproxy Pro when repo is not set."
}

variable "community_repo_default" {
  type        = string
  description = "Default repository for imgproxy community edition when repo is not set."
}

# Compute Configuration
variable "cpu" {
  type        = number
  description = "CPU allocation for the container."
}

variable "workers" {
  type        = number
  description = "Number of workers. When null, calculated as ceil(cpu * 2)."
}

variable "timeout" {
  type        = number
  description = "Request timeout in seconds."
}

variable "signature_size" {
  type        = number
  description = "Number of bytes from the key/salt used for signing."
}

# Environment Variables
variable "environment" {
  type        = map(string)
  description = "Additional environment variables passed to imgproxy."
}

# Provider-Specific Configuration
variable "secret_key_name" {
  type        = string
  description = "Key name for secret references ('id' for Azure, 'secret' for GCP)."
}

variable "storage_env_key" {
  type        = string
  description = "Environment variable key for storage ('IMGPROXY_USE_ABS' for Azure, 'IMGPROXY_USE_GCS' for GCP)."
}

variable "storage_enabled" {
  type        = bool
  description = "Whether storage is enabled."
}

variable "enable_monitoring" {
  type        = bool
  default     = false
  description = "Whether OpenTelemetry environment variables should be configured for imgproxy."
}

variable "otel_service_name" {
  type        = string
  default     = null
  description = "Service name exposed to OpenTelemetry when monitoring is enabled."
}

# Security & Secrets
variable "insecure" {
  type        = bool
  description = "Disable URL signature checks."
}

variable "secrets" {
  type = map(object({
    id      = string
    version = string
  }))
  description = "Map of environment variable names to secret references."
}

variable "keys_secret" {
  type = object({
    id      = string
    version = string
  })
  description = "Secret reference for imgproxy signing keys."
}

variable "salts_secret" {
  type = object({
    id      = string
    version = string
  })
  description = "Secret reference for imgproxy signing salts."
}

variable "secret_secret" {
  type = object({
    id      = string
    version = string
  })
  description = "Secret reference for authorization token."
}

variable "trusted_signatures_secret" {
  type = object({
    id      = string
    version = string
  })
  description = "Secret reference for trusted signature prefixes."
}

variable "source_url_encryption_key_secret" {
  type = object({
    id      = string
    version = string
  })
  description = "Secret reference for source URL encryption key."
}

variable "pro_license_key_secret" {
  type = object({
    id      = string
    version = string
  })
  description = "Secret reference for imgproxy Pro license key."
}
