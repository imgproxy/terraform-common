mock_provider "aws" {}

variables {
  service_name    = "imgproxy"
  alb_target_type = "ip"
  vpc_id          = "vpc-12345678"
  subnet_ids      = ["subnet-aaa111", "subnet-bbb222"]
  secret_arns     = ["arn:aws:secretsmanager:us-east-1:123456789012:secret:imgproxy/keys"]
}

run "task_role_created_by_default" {
  command = plan

  assert {
    condition     = length(aws_iam_role.task) == 1
    error_message = "Task IAM role must be created when task_role_arn is null"
  }

  assert {
    condition     = length(aws_iam_role_policy.task_marketplace) == 1
    error_message = "Marketplace IAM policy must be created when task role is auto-created"
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
    condition     = length(aws_iam_role_policy.task_marketplace) == 0
    error_message = "Marketplace policy must not be created when task_role_arn is provided"
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
    enable_cloudfront    = true
    alb_certificate_arns = ["arn:aws:acm:us-east-1:123456789012:certificate/abc"]
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
