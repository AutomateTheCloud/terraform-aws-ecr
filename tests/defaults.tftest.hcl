# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Offline tests: every provider is mocked, so no AWS account is used.
mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "us-east-1", description = "US East (N. Virginia)" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
}

variables {
  details    = { scope = "Test", purpose = "Defaults", environment = "test" }
  image_name = "app"
}

run "defaults_are_secure" {
  command = apply

  assert {
    condition     = aws_ecr_repository.this.name == "app"
    error_message = "Unexpected repository name."
  }
  assert {
    condition     = aws_ecr_repository.this.image_tag_mutability == "IMMUTABLE"
    error_message = "Tags must be immutable by default."
  }
  assert {
    condition     = aws_ecr_repository.this.image_scanning_configuration[0].scan_on_push
    error_message = "Scan on push must be on by default."
  }
  assert {
    condition     = !aws_ecr_repository.this.force_delete
    error_message = "force_delete must be off by default."
  }
  # Regression: the old module always created a repository policy, with an
  # unconditioned statement for the Lambda service principal.
  assert {
    condition     = length(aws_ecr_repository_policy.this) == 0
    error_message = "No repository policy is expected by default."
  }
  # Regression: lifecycle_rules was required although documented as optional.
  assert {
    condition     = length(aws_ecr_lifecycle_policy.this) == 0
    error_message = "No lifecycle policy is expected by default."
  }
  assert {
    condition = alltrue([
      output.metadata.ecr_repository_policy == null,
      output.metadata.ecr_lifecycle_policy == null,
      output.metadata.ecr_repository.name == "app",
      output.metadata.aws.region.abbr == "use1",
      output.metadata.aws.account.id == "111111111111",
    ])
    error_message = "Unexpected metadata output."
  }
}

run "tags" {
  command = plan
  variables {
    details = { scope = "Test", purpose = "Defaults", environment = "test", additional_tags = { CostCenter = "1234" } }
  }
  assert {
    condition = aws_ecr_repository.this.tags == tomap({
      Scope       = "Test"
      Purpose     = "Defaults"
      Environment = "test"
      CostCenter  = "1234"
      Name        = "app"
    })
    error_message = "Unexpected tags."
  }
}

run "namespace" {
  command = plan
  variables { namespace = "my-org/my-team" }
  assert {
    condition     = aws_ecr_repository.this.name == "my-org/my-team/app"
    error_message = "Unexpected repository name."
  }
}

run "options" {
  command = plan
  variables {
    enable_immutable_tags = false
    scan_on_push          = false
    force_delete          = true
  }
  assert {
    condition = alltrue([
      aws_ecr_repository.this.image_tag_mutability == "MUTABLE",
      !aws_ecr_repository.this.image_scanning_configuration[0].scan_on_push,
      aws_ecr_repository.this.force_delete,
    ])
    error_message = "Options were not applied."
  }
}

run "details_scope_required" {
  command = plan
  variables { details = { scope = " ", purpose = "p", environment = "e" } }
  expect_failures = [var.details]
}

# Regression: an empty abbreviation override used to replace the generated one with "".
run "abbreviation_override" {
  command = plan
  variables {
    details = { scope = "Automate the Cloud", scope_abbr = "atc-org", purpose = "Container Images", purpose_abbr = "", environment = "Production" }
  }
  assert {
    condition = alltrue([
      output.metadata.details.scope.abbr == "atc-org",
      output.metadata.details.scope.machine == "atcorg",
      output.metadata.details.purpose.abbr == "container_images",
      output.metadata.details.purpose.machine == "containerimages",
    ])
    error_message = "Unexpected abbreviations."
  }
}

# Regression: an empty image_name used to plan, and fail only at apply.
run "image_name_required" {
  command = plan
  variables { image_name = "" }
  expect_failures = [var.image_name]
}

run "image_name_no_uppercase" {
  command = plan
  variables { image_name = "My-App" }
  expect_failures = [var.image_name]
}

run "image_name_no_slash" {
  command = plan
  variables { image_name = "team/app" }
  expect_failures = [var.image_name]
}

run "image_name_too_short" {
  command = plan
  variables { image_name = "a" }
  expect_failures = [var.image_name]
}

run "namespace_validated" {
  command = plan
  variables { namespace = "team/" }
  expect_failures = [var.namespace]
}
