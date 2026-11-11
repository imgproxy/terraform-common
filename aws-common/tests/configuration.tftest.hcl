mock_provider "aws" {}

variables {
  service_name    = "imgproxy"
  alb_target_type = "ip"
  vpc_id          = "vpc-12345678"
  subnet_ids      = ["subnet-aaa111", "subnet-bbb222"]
  secret_arns     = ["arn:aws:secretsmanager:us-east-1:123456789012:secret:imgproxy/keys"]

  # Most tests plan a plain HTTP ALB; the TLS requirement has its own runs below.
  allow_insecure_http = true
}

run "task_role_created_by_default" {
  command = plan

  assert {
    condition     = length(aws_iam_role.task) == 1
    error_message = "Task IAM role must be created when task_role_arn is null"
  }

  assert {
    condition     = length(aws_iam_role_policy.task_autoscaling_metrics) == 1
    error_message = "Autoscaling metrics policy must be created when task role is auto-created"
  }
}

run "custom_task_role_skips_creation" {
  command = plan

  variables {
    task_role_arn = "arn:aws:iam::123456789012:role/existing-task-role"
  }

  assert {
    condition     = length(aws_iam_role.task) == 0
    error_message = "Task role must not be created when task_role_arn is provided"
  }

  assert {
    condition     = length(aws_iam_role_policy.task_autoscaling_metrics) == 0
    error_message = "Autoscaling metrics policy must not be created when task_role_arn is provided"
  }
}

run "execution_role_created_by_default" {
  command = plan

  assert {
    condition     = length(aws_iam_role.execution) == 1
    error_message = "Execution IAM role must be created when execution_role_arn is null"
  }
}

run "custom_execution_role_skips_creation" {
  command = plan

  variables {
    execution_role_arn = "arn:aws:iam::123456789012:role/existing-execution-role"
  }

  assert {
    condition     = length(aws_iam_role.execution) == 0
    error_message = "Execution role must not be created when execution_role_arn is provided"
  }
}

run "no_source_buckets_skips_s3_policy" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy.task_s3_source) == 0
    error_message = "S3 source policy must not be created when source_buckets is empty"
  }
}

run "source_buckets_creates_s3_policy" {
  command = plan

  variables {
    source_buckets = ["my-source-bucket"]
  }

  assert {
    condition     = length(aws_iam_role_policy.task_s3_source) == 1
    error_message = "S3 source policy must be created when source_buckets is non-empty"
  }
}

run "no_cache_bucket_skips_cache_policy" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy.task_s3_cache) == 0
    error_message = "S3 cache policy must not be created when cache_bucket is null"
  }
}

run "cache_bucket_creates_cache_policy" {
  command = plan

  variables {
    cache_bucket = "my-cache-bucket"
  }

  assert {
    condition     = length(aws_iam_role_policy.task_s3_cache) == 1
    error_message = "S3 cache policy must be created when cache_bucket is set"
  }
}

run "monitoring_creates_iam_policy" {
  command = plan

  variables {
    enable_monitoring = true
  }

  assert {
    condition     = length(aws_iam_role_policy.task_monitoring) == 1
    error_message = "Monitoring IAM policy must be created when enable_monitoring = true"
  }
}

run "monitoring_disabled_skips_iam_policy" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy.task_monitoring) == 0
    error_message = "Monitoring IAM policy must not be created by default"
  }
}

run "secrets_create_execution_policy" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy.execution_secrets) == 1
    error_message = "Execution secrets policy must be created when secret_arns is non-empty"
  }
}

run "no_secrets_skips_execution_policy" {
  command = plan

  variables {
    secret_arns = []
  }

  assert {
    condition     = length(aws_iam_role_policy.execution_secrets) == 0
    error_message = "Execution secrets policy must not be created when secret_arns is empty"
  }
}

run "ip_target_type_applied" {
  command = plan

  assert {
    condition     = aws_lb_target_group.main[0].target_type == "ip"
    error_message = "Target group must use the configured target type"
  }
}

run "instance_target_type_applied" {
  command = plan

  variables {
    alb_target_type = "instance"
  }

  assert {
    condition     = aws_lb_target_group.main[0].target_type == "instance"
    error_message = "Target group must use the configured target type"
  }
}

run "autoscaling_metrics_policy_always_created" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy.task_autoscaling_metrics) == 1
    error_message = "Autoscaling metrics policy must be created whenever the task role is auto-created"
  }
}

run "autoscaling_metrics_policy_skipped_with_custom_role" {
  command = plan

  variables {
    task_role_arn = "arn:aws:iam::123456789012:role/existing-task-role"
  }

  assert {
    condition     = length(aws_iam_role_policy.task_autoscaling_metrics) == 0
    error_message = "Autoscaling metrics policy must not be created when task_role_arn is provided"
  }
}

run "cloudfront_disabled_has_no_origin_lock" {
  command = plan

  assert {
    condition     = length(random_password.origin_verify) == 0
    error_message = "No origin secret must be generated when CloudFront is disabled"
  }

  assert {
    condition     = length(aws_lb_listener_rule.http_origin_verify) == 0
    error_message = "No origin verify rule must exist when CloudFront is disabled"
  }

  assert {
    condition     = aws_lb_listener.http[0].default_action[0].type == "forward"
    error_message = "Listener must forward by default when CloudFront is disabled"
  }
}

run "cloudfront_http_only_origin_opens_only_port_80" {
  command = plan

  variables {
    enable_cloudfront = true
  }

  assert {
    condition     = length(aws_security_group.alb[0].ingress) == 1 && one(aws_security_group.alb[0].ingress).from_port == 80
    error_message = "Only port 80 must be opened to CloudFront for an http-only origin"
  }

  assert {
    condition     = aws_lb_listener.http[0].default_action[0].type == "fixed-response"
    error_message = "HTTP listener must reject requests without the origin secret"
  }

  assert {
    condition     = length(aws_lb_listener_rule.http_origin_verify) == 1 && length(aws_lb_listener_rule.https_origin_verify) == 0
    error_message = "Only the HTTP origin verify rule must exist without a certificate"
  }

  assert {
    condition     = length(random_password.origin_verify) == 1
    error_message = "An origin secret must be generated by default"
  }
}

run "cloudfront_https_origin_opens_only_port_443" {
  command = plan

  variables {
    enable_cloudfront        = true
    alb_certificate_arns     = ["arn:aws:acm:us-east-1:123456789012:certificate/abc"]
    cloudfront_origin_domain = "origin.example.com"
  }

  assert {
    condition     = contains([for o in aws_cloudfront_distribution.main[0].origin : o.domain_name], "origin.example.com")
    error_message = "CloudFront must reach the ALB through cloudfront_origin_domain"
  }

  assert {
    condition     = length(aws_security_group.alb[0].ingress) == 1 && one(aws_security_group.alb[0].ingress).from_port == 443
    error_message = "Only port 443 must be opened to CloudFront for an https-only origin"
  }

  assert {
    condition     = aws_lb_listener.https[0].default_action[0].type == "fixed-response"
    error_message = "HTTPS listener must reject requests without the origin secret"
  }

  assert {
    condition     = length(aws_lb_listener_rule.https_origin_verify) == 1 && length(aws_lb_listener_rule.http_origin_verify) == 0
    error_message = "Only the HTTPS origin verify rule must exist when the HTTP listener redirects"
  }
}

run "cloudfront_custom_origin_secret_skips_generation" {
  command = plan

  variables {
    enable_cloudfront               = true
    cloudfront_origin_verify_secret = "supplied-secret"
  }

  assert {
    condition     = length(random_password.origin_verify) == 0
    error_message = "No secret must be generated when one is supplied"
  }
}

run "rejects_plain_http_by_default" {
  command = plan

  variables {
    allow_insecure_http = false
  }

  expect_failures = [terraform_data.checks]
}

run "accepts_certificate_without_insecure_flag" {
  command = plan

  variables {
    allow_insecure_http  = false
    alb_certificate_arns = ["arn:aws:acm:us-east-1:123456789012:certificate/abc"]
  }

  assert {
    condition     = length(aws_lb_listener.https) == 1
    error_message = "An ALB with a certificate must not need allow_insecure_http"
  }
}

run "rejects_cloudfront_https_origin_without_origin_domain" {
  command = plan

  variables {
    enable_cloudfront    = true
    alb_certificate_arns = ["arn:aws:acm:us-east-1:123456789012:certificate/abc"]
  }

  expect_failures = [terraform_data.checks]
}

run "rejects_origin_domain_without_certificate" {
  command = plan

  variables {
    enable_cloudfront        = true
    cloudfront_origin_domain = "origin.example.com"
  }

  expect_failures = [terraform_data.checks]
}

run "rejects_origin_domain_without_cloudfront" {
  command = plan

  variables {
    alb_certificate_arns     = ["arn:aws:acm:us-east-1:123456789012:certificate/abc"]
    cloudfront_origin_domain = "origin.example.com"
  }

  expect_failures = [terraform_data.checks]
}

run "rejects_origin_domain_equal_to_cloudfront_domain" {
  command = plan

  variables {
    enable_cloudfront          = true
    alb_certificate_arns       = ["arn:aws:acm:us-east-1:123456789012:certificate/abc"]
    cloudfront_origin_domain   = "cdn.example.com"
    cloudfront_domains         = ["cdn.example.com"]
    cloudfront_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/def"
  }

  expect_failures = [terraform_data.checks]
}

# ── Lambda mode ───────────────────────────────────────────────────────────────

run "lambda_creates_function_role_only" {
  command = plan

  variables {
    compute_platform = "lambda"
    create_alb       = false
    log_group_name   = "/aws/lambda/imgproxy"
  }

  assert {
    condition     = length(aws_iam_role.task) == 1 && length(aws_iam_role.execution) == 0
    error_message = "Lambda mode must create the function role and no ECS execution role"
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.lambda_basic) == 1 && length(aws_iam_role_policy_attachment.lambda_vpc) == 0
    error_message = "Lambda mode must attach the basic execution policy, and the VPC one only with lambda_vpc_access"
  }

  assert {
    condition     = length(aws_iam_role_policy.task_autoscaling_metrics) == 0
    error_message = "ECS autoscaling policy must not be created in Lambda mode"
  }

  assert {
    condition     = aws_cloudwatch_log_group.main.name == "/aws/lambda/imgproxy"
    error_message = "Log group must use log_group_name"
  }
}

run "lambda_vpc_access_attaches_vpc_policy" {
  command = plan

  variables {
    compute_platform  = "lambda"
    create_alb        = false
    lambda_vpc_access = true
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.lambda_vpc) == 1
    error_message = "VPC access policy must be attached with lambda_vpc_access"
  }
}

run "lambda_cloudfront_uses_origin_access_control" {
  command = plan

  variables {
    compute_platform    = "lambda"
    create_alb          = false
    enable_cloudfront   = true
    lambda_function_url = "https://abc123.lambda-url.us-east-1.on.aws/"
  }

  assert {
    condition     = length(aws_cloudfront_distribution.main) == 1 && length(aws_cloudfront_origin_access_control.lambda) == 1
    error_message = "CloudFront in Lambda mode must create a distribution and an origin access control"
  }
}

run "lambda_rejects_alb" {
  command = plan

  variables {
    compute_platform = "lambda"
    create_alb       = true
  }

  expect_failures = [terraform_data.checks]
}

run "lambda_cloudfront_requires_function_url" {
  command = plan

  variables {
    compute_platform  = "lambda"
    create_alb        = false
    enable_cloudfront = true
  }

  expect_failures = [terraform_data.checks]
}

run "rejects_unknown_compute_platform" {
  command = plan

  variables {
    compute_platform = "batch"
  }

  expect_failures = [var.compute_platform]
}
