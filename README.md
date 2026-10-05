# Terraform module for Amazon ECR repositories

Creates an Amazon Elastic Container Registry (ECR) repository, which stores container images for Docker, Amazon ECS, Amazon EKS and AWS Lambda, with its lifecycle policy and repository policy.

The defaults are the settings most repositories should have. A repository created with only the required inputs can be used only by its own account, never lets a tag be overwritten by a different image, scans every pushed image for known vulnerabilities, and encrypts images at rest.

## What it configures

| Setting | Default | Input |
|---|---|---|
| Access for other accounts and services | None | `policy` |
| Tag immutability | On: a tag cannot be moved to another image | `enable_immutable_tags` |
| Scan on push | On (basic scanning) | `scan_on_push` |
| Encryption at rest | AES-256, with keys ECR manages | Not configurable |
| Lifecycle rules | None: every image is kept | `lifecycle_rules` |
| Delete images on destroy | Off | `force_delete` |
| Repository name prefix | None | `namespace` |

## Usage

```hcl
module "ecr" {
  source  = "AutomateTheCloud/ecr/aws"
  version = "~> 1.0"

  details = {
    scope       = "Automate the Cloud"
    purpose     = "Web Site"
    environment = "Production"
  }

  image_name = "web-site"

  lifecycle_rules = [
    {
      priority    = 1
      description = "Delete untagged images after 14 days"
      selection   = { tag_status = "untagged", count_type = "sinceImagePushed", count_unit = "days", count_number = 14 }
    }
  ]
}
```

`details` and `image_name` are the only required inputs. `details` sets the `Scope`, `Purpose` and `Environment` tags on every resource.

Push to the repository with the URL in `module.ecr.metadata.ecr_repository.repository_url`:

```shell
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account ID>.dkr.ecr.us-east-1.amazonaws.com
docker push <repository_url>:v1.0.0
```

The module uses your default `aws` provider and creates everything in that provider's Region. To create the repository somewhere else without configuring another provider, set `region`:

```hcl
module "ecr_us_west_2" {
  source  = "AutomateTheCloud/ecr/aws"
  version = "~> 1.0"

  region     = "us-west-2"
  details    = { scope = "Automate the Cloud", purpose = "Web Site", environment = "Production" }
  image_name = "web-site"
}
```

Because `region` is an ordinary input, one module block can create a repository in each of several Regions with `for_each`.

To use a provider configured for another account, pass it explicitly with `providers = { aws = aws.other_account }`.

## The `details` input

Most modules ask only for what the resource itself needs. This one also requires `details`: three names that say what the repository belongs to, what it is for, and which environment it is in. Every Automate the Cloud module takes the same input, and requiring it is deliberate.

```hcl
details = {
  scope       = "Automate the Cloud" # what it belongs to: an organization, team or project
  purpose     = "Web Site"           # what it is for
  environment = "Production"         # which environment
}
```

**Every resource can be traced.** The three names become the `Scope`, `Purpose` and `Environment` tags on every resource the module creates. Months later, anyone looking at a repository in the AWS console, or at a line on the bill, can see who it belongs to and why it exists. With cost allocation tags turned on in AWS Billing, the same tags split your bill by project and environment. Because the input is required and checked, no resource can be created without them.

**One definition for a whole stack.** Write `details` once and pass the same value to every module, so the repository, the service that runs its images, its DNS zone and everything else are tagged alike. Tags you want everywhere, such as a cost center or the Terraform workspace, go in `additional_tags`:

```hcl
locals {
  details = {
    scope           = "Automate the Cloud"
    purpose         = "Web Site"
    environment     = "Production"
    additional_tags = { CostCenter = "1234", IaC = "true" }
  }
}

module "site_images" {
  source  = "AutomateTheCloud/ecr/aws"
  version = "~> 1.0"

  details    = local.details
  image_name = "example-web-site"
}
```

**Consistent names.** The module turns each name into two short forms other resources can be named with: `abbr`, lowercase with words joined by underscores (`Web Site` becomes `web_site`), and `machine`, lowercase letters and numbers only (`website`), for resources that allow no underscores. It also works out a short form of the Region, such as `use1` for `us-east-1`. Every module derives these the same way, so names stay consistent across a stack. To choose your own short forms, set `scope_abbr`, `purpose_abbr` or `environment_abbr`, for example `environment_abbr = "prd"`.

**One output to reach everything.** All of it comes back in the `metadata` output, along with everything the module created, so a configuration needs only one reference: `module.site_images.metadata.ecr_repository.repository_url` for the repository's URL, or `module.site_images.metadata.aws.region.abbr` for the Region's short form.

## Examples

Each example is a complete configuration you can run with `terraform init` and `terraform apply`.

- [Basic repository](https://github.com/AutomateTheCloud/terraform-aws-ecr/tree/main/examples/basic): a private repository that deletes untagged images after 14 days.
- [Lambda](https://github.com/AutomateTheCloud/terraform-aws-ecr/tree/main/examples/lambda): a repository that AWS Lambda functions in the same account and Region can pull images from.
- [Complete](https://github.com/AutomateTheCloud/terraform-aws-ecr/tree/main/examples/complete): most of the module's options in one repository, with read access for other accounts.

## Things to know

### Access for other accounts and services

By default the module creates no repository policy, and only the repository's own account can use it, through its IAM policies. `policy.aws_account_read_access` and `policy.aws_organization_read_access` let other accounts pull and list images. Each of those accounts must still allow its own users and roles to pull, with an IAM policy that includes `ecr:GetAuthorizationToken`; a repository policy cannot grant that action.

For anything else, such as letting another account push images, write the statements yourself and pass them in `policy.source_policy_documents`.

If a statement names an IAM role created in the same apply, the next plan can show that principal changing from the role's unique ID (`AROA...`) to its ARN, because IAM had not finished setting up the new role when ECR saved the policy. Run `terraform apply -refresh-only` once and the difference goes away.

### AWS Lambda

A Lambda function can run a container image from ECR only if the repository policy lets the Lambda service pull it. The module does not add that grant on its own. The [Lambda example](https://github.com/AutomateTheCloud/terraform-aws-ecr/tree/main/examples/lambda) adds one through `policy.source_policy_documents`, limited to functions in the same account and Region.

### Immutable tags

With immutable tags, the default, pushing an image with a tag that already exists fails. Give every build its own tag, such as a version number or a commit ID. To use moving tags such as `latest`, set `enable_immutable_tags = false`.

### Lifecycle rules

ECR checks lifecycle rules in order of `priority`, and an image is counted by only the first rule that matches it. A rule with `tag_status = "any"` must have the highest priority number. Deleted images cannot be recovered, so check a new rule with the lifecycle policy preview in the ECR console before you rely on it. The module checks rules at plan time for the mistakes ECR would reject.

### Encryption

Images are encrypted at rest with AES-256, using keys ECR manages. The module does not offer AWS Key Management Service (KMS) encryption: a repository's encryption setting cannot be changed after it is created, so changing it would replace the repository and delete every image in it.

### Deleting a repository

Terraform cannot destroy a repository that still holds images, so images are never deleted by accident. Terraform removes the repository's policies before it tries to delete the repository, so a destroy that fails this way leaves the repository without them until the next apply. Set `force_delete = true`, and apply, before destroying a repository whose images you no longer need.

### Renaming a repository

Changing `namespace` or `image_name` replaces the repository: Terraform deletes the old one, with every image in it, and creates an empty one. To rename a repository, create the new one, copy the images across, then remove the old one.

## Contributing

Contributions are welcome, after review. Read [CONTRIBUTING.md](https://github.com/AutomateTheCloud/terraform-aws-ecr/blob/main/CONTRIBUTING.md) before opening a pull request, and report security problems as described in [SECURITY.md](https://github.com/AutomateTheCloud/terraform-aws-ecr/blob/main/SECURITY.md).

## Testing

The tests in `tests/` run offline against mocked AWS providers, so they need no AWS account:

```shell
terraform init
terraform test
```

## Reference

The sections below are generated from the code by [terraform-docs](https://terraform-docs.io). To update them, run `terraform-docs .`.

<!-- BEGIN_TF_DOCS -->
### Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement_terraform) (>= 1.9)

- <a name="requirement_aws"></a> [aws](#requirement_aws) (>= 6.0)

### Required Inputs

The following input variables are required:

#### <a name="input_details"></a> [details](#input_details)

Description: Names and tags shared by every resource in the module. `scope`, `purpose` and `environment` become the `Scope`, `Purpose` and `Environment` tags, and are converted to abbreviations that other modules can use in resource names (see the `metadata` output). [The `details` input](https://github.com/AutomateTheCloud/terraform-aws-ecr#the-details-input) explains why it is required.

- `scope` - (Required) What the resource belongs to, such as an organization or project: `Automate the Cloud`.
- `purpose` - (Required) What the resource is for: `Web Site`.
- `environment` - (Required) The environment: `Production`.
- `scope_abbr`, `purpose_abbr`, `environment_abbr` - (Optional) Abbreviations to use instead of the generated ones, which are lowercase with words joined by underscores (`Web Site` becomes `web_site`).
- `additional_tags` - (Optional) More tags for every resource, such as `{ CostCenter = "1234" }`.

Type:

```hcl
object({
    scope            = string
    scope_abbr       = optional(string)
    purpose          = string
    purpose_abbr     = optional(string)
    environment      = string
    environment_abbr = optional(string)
    additional_tags  = optional(map(string), {})
  })
```

#### <a name="input_image_name"></a> [image_name](#input_image_name)

Description: The name of the repository, after the optional `namespace`: `app` gives the repository `app`, or `my-team/app` with `namespace = "my-team"`. Lowercase letters and numbers, with single periods, underscores or hyphens between them. Changing it, or `namespace`, replaces the repository and deletes every image in it.

Type: `string`

### Optional Inputs

The following input variables are optional (have default values):

#### <a name="input_enable_immutable_tags"></a> [enable_immutable_tags](#input_enable_immutable_tags)

Description: Make image tags immutable, so a pushed tag such as `v1.2.0` can never be overwritten by a different image. Set to `false` to allow tags such as `latest` to be moved to newer images.

Type: `bool`

Default: `true`

#### <a name="input_force_delete"></a> [force_delete](#input_force_delete)

Description: Delete every image in the repository when it is destroyed. Without it, Terraform cannot destroy a repository that still holds images. Deleted images cannot be recovered.

Type: `bool`

Default: `false`

#### <a name="input_lifecycle_rules"></a> [lifecycle_rules](#input_lifecycle_rules)

Description: Lifecycle rules, which delete old images automatically, for example untagged images or all but the newest 100. An empty list, the default, creates no lifecycle policy and keeps every image. ECR applies the rules in order of `priority`, and an image is counted by only the first rule that matches it. See [Amazon ECR lifecycle policies](https://docs.aws.amazon.com/AmazonECR/latest/userguide/LifecyclePolicies.html).

Each rule takes:

- `priority` - (Required) A unique whole number, 1 or more. Lower numbers are applied first. A rule with `tag_status = "any"` must have the highest number.
- `description` - (Optional) What the rule is for.
- `selection` - (Required) Which images the rule deletes:

  - `tag_status` - (Required) `untagged`, `tagged` or `any`.
  - `tag_prefix_list` - (Optional) For `tagged` only: images with a tag starting with one of these, such as `["v"]`.
  - `tag_pattern_list` - (Optional) For `tagged` only: images with a tag matching one of these patterns, where `*` matches any characters, such as `["*-rc*"]`. A `tagged` rule needs exactly one of `tag_prefix_list` or `tag_pattern_list`.
  - `count_type` - (Required) `imageCountMoreThan`, to keep only the newest `count_number` images, or `sinceImagePushed`, to delete images older than `count_number` days.
  - `count_unit` - (Optional) `days`. Required with `sinceImagePushed`, and not allowed with `imageCountMoreThan`.
  - `count_number` - (Required) A whole number, 1 or more.

Matching images are deleted (the `expire` action). Deleted images cannot be recovered.

Type:

```hcl
list(object({
    priority    = number
    description = optional(string)
    selection = object({
      tag_status       = string
      tag_prefix_list  = optional(list(string))
      tag_pattern_list = optional(list(string))
      count_type       = string
      count_unit       = optional(string)
      count_number     = number
    })
  }))
```

Default: `[]`

#### <a name="input_namespace"></a> [namespace](#input_namespace)

Description: A prefix for the repository name, such as `my-team` or `my-org/my-team`, which groups repositories. The repository is named `<namespace>/<image_name>`. Empty, the default, means no prefix.

Type: `string`

Default: `""`

#### <a name="input_policy"></a> [policy](#input_policy)

Description: The repository policy, which lets other AWS accounts and services use the repository. A policy is created only when an option below grants access; by default there is none, and only the repository's own account, through its IAM policies, can use it.

- `aws_account_read_access` - (Optional) 12-digit AWS account IDs that may pull and list images. Each account still needs an IAM policy for its users and roles, including `ecr:GetAuthorizationToken`.
- `aws_organization_read_access` - (Optional) The same, for every account in an AWS Organization, by organization ID (`o-xxxxxxxxxx`).
- `source_policy_documents` - (Optional) JSON policy documents whose statements are added to the policy, for anything the options above do not cover, such as letting AWS Lambda pull images or another account push them. Statement IDs (`Sid`) must be unique across the whole policy. See the [Lambda example](https://github.com/AutomateTheCloud/terraform-aws-ecr/tree/main/examples/lambda).

Type:

```hcl
object({
    aws_account_read_access      = optional(list(string), [])
    aws_organization_read_access = optional(list(string), [])
    source_policy_documents      = optional(list(string), [])
  })
```

Default: `{}`

#### <a name="input_region"></a> [region](#input_region)

Description: The AWS Region to create the repository and its policies in, such as `us-west-2`. Defaults to the Region of the AWS provider passed to the module.

Type: `string`

Default: `null`

#### <a name="input_scan_on_push"></a> [scan_on_push](#input_scan_on_push)

Description: Scan each image for known software vulnerabilities when it is pushed (ECR basic scanning, at no extra cost). Findings are shown in the ECR console and by `aws ecr describe-image-scan-findings`. If the registry has its own scanning configuration, such as Amazon Inspector enhanced scanning, that configuration applies instead.

Type: `bool`

Default: `true`

### Outputs

The following outputs are exported:

#### <a name="output_metadata"></a> [metadata](#output_metadata)

Description: Everything the module created, in one object, so that other configurations need only one reference:

- `details` - The scope, purpose and environment, each with its `name`, `abbr` (lowercase, words joined by underscores) and `machine` (lowercase letters and numbers only) forms, and the `tags` applied to every resource.
- `aws` - The `account.id`, and the `region` `name`, `abbr` (such as `use1` for `us-east-1`) and `description`.
- `ecr_repository` - The repository's `name`, `arn`, `repository_url` (for `docker push` and `docker pull`), `registry_id`, `region`, `image_tag_mutability`, `image_scanning_configuration`, `encryption_configuration`, `force_delete`, `id`, `tags` and `tags_all`.
- `ecr_repository_policy` - The repository policy's `policy` JSON, `repository`, `registry_id`, `region` and `id`. `null` when no policy is created.
- `ecr_lifecycle_policy` - The lifecycle policy's `policy` JSON, `repository`, `registry_id`, `region` and `id`. `null` when there are no lifecycle rules.
<!-- END_TF_DOCS -->

## License

This module is licensed under the [Apache License 2.0](https://github.com/AutomateTheCloud/terraform-aws-ecr/blob/main/LICENSE). See [NOTICE](https://github.com/AutomateTheCloud/terraform-aws-ecr/blob/main/NOTICE) for the copyright notice.

The Automate the Cloud name and logo are not covered by this license.

---

Maintained by [Automate the Cloud](https://automatethe.cloud), a Kentucky 501(c)(3) that teaches cloud infrastructure and helps nonprofits run theirs.
