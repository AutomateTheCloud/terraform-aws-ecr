# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

output "metadata" {
  description = <<-EOT
    Everything the module created, in one object, so that other configurations need only one reference:

    - `details` - The scope, purpose and environment, each with its `name`, `abbr` (lowercase, words joined by underscores) and `machine` (lowercase letters and numbers only) forms, and the `tags` applied to every resource.
    - `aws` - The `account.id`, and the `region` `name`, `abbr` (such as `use1` for `us-east-1`) and `description`.
    - `ecr_repository` - The repository's `name`, `arn`, `repository_url` (for `docker push` and `docker pull`), `registry_id`, `region`, `image_tag_mutability`, `image_scanning_configuration`, `encryption_configuration`, `force_delete`, `id`, `tags` and `tags_all`.
    - `ecr_repository_policy` - The repository policy's `policy` JSON, `repository`, `registry_id`, `region` and `id`. `null` when no policy is created.
    - `ecr_lifecycle_policy` - The lifecycle policy's `policy` JSON, `repository`, `registry_id`, `region` and `id`. `null` when there are no lifecycle rules.
  EOT
  value = {
    details = {
      scope = {
        name    = local.scope.name
        abbr    = local.scope.abbr
        machine = local.scope.machine
      }
      purpose = {
        name    = local.purpose.name
        abbr    = local.purpose.abbr
        machine = local.purpose.machine
      }
      environment = {
        name    = local.environment.name
        abbr    = local.environment.abbr
        machine = local.environment.machine
      }
      tags = local.tags
    }

    aws = {
      account = {
        id = local.aws.account.id
      }
      region = {
        name        = local.aws.region.name
        abbr        = local.aws.region.abbr
        description = local.aws.region.description
      }
    }

    # One entry per resource. Resources that are not created are null.
    ecr_repository        = local.output_resources.ecr_repository
    ecr_repository_policy = local.output_resources.ecr_repository_policy
    ecr_lifecycle_policy  = local.output_resources.ecr_lifecycle_policy
  }
}

locals {
  # Each resource's attributes are listed one by one. Referencing a whole resource
  # would also reference any attribute the provider deprecates later, and every
  # caller's plan would print deprecation warnings.
  output_resources = {
    # Left out: image_tag_mutability_exclusion_filter, which the provider floor (6.0)
    # does not have, and timeouts.
    ecr_repository = {
      arn                          = aws_ecr_repository.this.arn
      encryption_configuration     = aws_ecr_repository.this.encryption_configuration
      force_delete                 = aws_ecr_repository.this.force_delete
      id                           = aws_ecr_repository.this.id
      image_scanning_configuration = aws_ecr_repository.this.image_scanning_configuration
      image_tag_mutability         = aws_ecr_repository.this.image_tag_mutability
      name                         = aws_ecr_repository.this.name
      region                       = aws_ecr_repository.this.region
      registry_id                  = aws_ecr_repository.this.registry_id
      repository_url               = aws_ecr_repository.this.repository_url
      tags                         = aws_ecr_repository.this.tags
      tags_all                     = aws_ecr_repository.this.tags_all
    }

    ecr_repository_policy = length(aws_ecr_repository_policy.this) == 0 ? null : {
      id          = aws_ecr_repository_policy.this[0].id
      policy      = aws_ecr_repository_policy.this[0].policy
      region      = aws_ecr_repository_policy.this[0].region
      registry_id = aws_ecr_repository_policy.this[0].registry_id
      repository  = aws_ecr_repository_policy.this[0].repository
    }

    ecr_lifecycle_policy = length(aws_ecr_lifecycle_policy.this) == 0 ? null : {
      id          = aws_ecr_lifecycle_policy.this[0].id
      policy      = aws_ecr_lifecycle_policy.this[0].policy
      region      = aws_ecr_lifecycle_policy.this[0].region
      registry_id = aws_ecr_lifecycle_policy.this[0].registry_id
      repository  = aws_ecr_lifecycle_policy.this[0].repository
    }
  }
}
