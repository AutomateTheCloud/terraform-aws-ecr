# Repository for AWS Lambda images

A private repository that AWS Lambda functions can run container images from. The repository policy lets the Lambda service pull images only for functions in the same account and Region, through `policy.source_policy_documents`. Without such a statement, creating a function from an image in the repository fails.

The example creates the repository only. Push an image to it, then use the `repository_url` output, followed by `:<tag>`, as the function's image URI.

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

#### <a name="output_repository_url"></a> [repository_url](#output_repository_url)

Description: Use as the image URI of a Lambda function, followed by :<tag>
<!-- END_TF_DOCS -->
