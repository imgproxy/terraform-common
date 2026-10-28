# terraform-common

Internal Terraform modules shared across imgproxy deployments. They hold logic that is identical across the platform-specific modules, so it lives in one place.

These modules are internal: they are called by the platform modules and are not intended for direct use.

## Modules

| Module | Description |
|--------|-------------|
| [`aws-common`](aws-common/) | AWS infrastructure shared by EC2 and Fargate deployments: IAM roles, CloudWatch log group, Application Load Balancer and optional CloudFront distribution. |
| [`imgproxy-common`](imgproxy-common/) | Data-only module with imgproxy configuration logic shared by the Azure and Google Cloud modules. Creates no resources. |

## Requirements

- Terraform >= 1.5
