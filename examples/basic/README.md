# Basic repository

A private repository with the module's defaults: immutable tags, scan on push, and no access for other accounts. A lifecycle rule deletes images that have no tag 14 days after they were pushed.

## Run it

```shell
terraform init
terraform apply
```

Remove it with `terraform destroy`. Destroying fails if the repository still holds images, so images are never deleted by accident.

<!-- BEGIN_TF_DOCS -->
### Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement_terraform) (>= 1.9)

- <a name="requirement_aws"></a> [aws](#requirement_aws) (~> 6.0)

### Outputs

The following outputs are exported:

#### <a name="output_repository"></a> [repository](#output_repository)

Description: Name, ARN and URL of the repository
<!-- END_TF_DOCS -->
