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

See `variables.tf` and `outputs.tf` for the full list.

## Requirements

- Terraform >= 1.5
- AWS provider ~> 5.0
