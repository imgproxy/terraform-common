# terraform-common

Internal Terraform modules shared across imgproxy deployments. They hold logic that is identical across the platform-specific modules, so it lives in one place.

These modules are internal and are not intended for direct use. They are not fetched over git: each platform module vendors a copy under its own `modules/` directory (see [Syncing](#syncing)).

## Modules

| Module | Description |
|--------|-------------|
| [`aws-common`](aws-common/) | AWS infrastructure shared by EC2 and Fargate deployments: IAM roles, CloudWatch log group, Application Load Balancer and optional CloudFront distribution. |
| [`imgproxy-common`](imgproxy-common/) | Data-only module with imgproxy configuration logic shared by the Azure and Google Cloud modules. Creates no resources. |

## Syncing

`sync.sh` copies the shared modules into the sibling platform repos. It expects them checked out next to this repository.

```bash
./sync.sh                         # all targets
./sync.sh terraform-google-imgproxy   # one target
```

| Target | Modules copied to `modules/` |
|--------|------------------------------|
| `terraform-google-imgproxy` | `imgproxy-common` |

The copies are overwritten on every run, so never edit them in the platform repos: change the module here, run the script and commit the result there. To add a target, add a line to `TARGETS` in `sync.sh`.

## Requirements

- Terraform >= 1.5
