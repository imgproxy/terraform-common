# AWS Common Module

Internal module that provides shared AWS infrastructure for imgproxy deployments on both ECS EC2 and Fargate.

## Purpose

Extracts everything that does not depend on how the container runs, so the compute-specific modules only define the ECS cluster, task definition and service.

## What This Module Provides

- **IAM**: task execution role and task role (or pass existing ones via `execution_role_arn` / `task_role_arn`)
- **CloudWatch**: log group with configurable retention
- **ALB**: security group, load balancer, target group, HTTP/HTTPS listeners (when `create_alb = true`)
- **CloudFront**: cache policy and distribution in front of the ALB (when `enable_cloudfront = true`)

## Usage

This module is called internally by the AWS compute modules. It is not intended for direct use.

## Outputs

- `task_role_arn`, `execution_role_arn`: IAM role ARNs
- `log_group_name`: CloudWatch log group name
- `alb_sg_id`, `target_group_arn`: for the ECS service and security group rules
- `alb_dns_name`, `alb_zone_id`, `cloudfront_domain_name`, `cloudfront_hosted_zone_id`: for DNS records
- `url`: imgproxy endpoint (CloudFront domain if enabled, otherwise ALB DNS name)

## TLS

The module is secure by default and fails at plan time (`terraform_data.checks`) when:

- `create_alb = true` without `alb_certificate_arns`, unless `allow_insecure_http = true`. Plain HTTP is for testing only: requests, signed URLs and tokens are unencrypted.
- `enable_cloudfront = true` and `alb_certificate_arns` is set without `cloudfront_origin_domain`. CloudFront validates the ALB certificate against the origin domain name, so it cannot connect to the ALB's own `*.elb.amazonaws.com` name with a certificate for your domain. Point a DNS record for `cloudfront_origin_domain` at the ALB (`alb_dns_name` / `alb_zone_id` outputs) and cover it with a certificate in `alb_certificate_arns`.
- `cloudfront_origin_domain` is set without CloudFront, without a certificate, or equal to one of `cloudfront_domains`.

CloudFront with `allow_insecure_http = true` and no certificate reaches the ALB over plain HTTP, which sends the origin secret header and all traffic in clear text. Use it for testing only.

## CloudFront origin lock

- The ALB returns `403` unless the request carries the `X-Origin-Verify` secret that CloudFront adds, because the CloudFront prefix list admits every distribution.
- The secret is generated unless `cloudfront_origin_verify_secret` is set.
- Only port 443 (with `alb_certificate_arns`) or port 80 (without) is opened to CloudFront, to stay under the 60-rule security group limit.
- Listeners wait for the CloudFront distribution to deploy, so a single apply is enough on upgrade (a few seconds of `403` are possible while the listener rule is created).

See `variables.tf` and `outputs.tf` for the full list.

## Requirements

- Terraform >= 1.5
- AWS provider ~> 5.0
- Random provider >= 3.0
