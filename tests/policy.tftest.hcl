# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

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
  details    = { scope = "Test", purpose = "Policy", environment = "test" }
  image_name = "app"
}

run "account_read_access" {
  command = apply
  variables {
    policy = { aws_account_read_access = ["222222222222", "123456789012"] }
  }
  assert {
    condition     = length(jsondecode(aws_ecr_repository_policy.this[0].policy).Statement) == 1
    error_message = "Expected one statement."
  }
  assert {
    condition = jsondecode(aws_ecr_repository_policy.this[0].policy).Statement[0].Principal.AWS == [
      "arn:aws:iam::222222222222:root",
      "arn:aws:iam::123456789012:root",
    ]
    error_message = "Accounts must be given as root ARNs in the provider's partition."
  }
  assert {
    condition     = contains(jsondecode(aws_ecr_repository_policy.this[0].policy).Statement[0].Action, "ecr:BatchGetImage")
    error_message = "Read access must allow pulling."
  }
  assert {
    condition     = !contains(jsondecode(aws_ecr_repository_policy.this[0].policy).Statement[0].Action, "ecr:GetAuthorizationToken")
    error_message = "GetAuthorizationToken has no effect in a repository policy."
  }
  assert {
    condition     = output.metadata.ecr_repository_policy != null
    error_message = "The policy must be in the output."
  }
}

run "partition_from_provider" {
  command = apply
  override_data {
    target = data.aws_partition.this
    values = { partition = "aws-us-gov" }
  }
  variables {
    policy = { aws_account_read_access = ["222222222222"] }
  }
  assert {
    condition     = jsondecode(aws_ecr_repository_policy.this[0].policy).Statement[0].Principal.AWS == ["arn:aws-us-gov:iam::222222222222:root"]
    error_message = "ARNs must use the provider's partition."
  }
}

run "organization_read_access" {
  command = apply
  variables {
    policy = { aws_organization_read_access = ["o-abcdefghij", "o-0123456789"] }
  }
  assert {
    condition = jsondecode(aws_ecr_repository_policy.this[0].policy).Statement[0] == {
      Sid       = "OrganizationReadAccess"
      Effect    = "Allow"
      Principal = "*"
      Action = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:DescribeImageScanFindings",
        "ecr:DescribeImages",
        "ecr:DescribeRepositories",
        "ecr:GetDownloadUrlForLayer",
        "ecr:ListImages",
      ]
      Condition = { StringEquals = { "aws:PrincipalOrgID" = ["o-abcdefghij", "o-0123456789"] } }
    }
    error_message = "Unexpected organization statement."
  }
}

run "source_policy_documents" {
  command = apply
  variables {
    policy = {
      aws_account_read_access = ["222222222222"]
      source_policy_documents = [jsonencode({
        Version = "2012-10-17"
        Statement = [{
          Sid       = "LambdaPull"
          Effect    = "Allow"
          Principal = { Service = "lambda.amazonaws.com" }
          Action    = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
          Condition = { StringLike = { "aws:sourceArn" = "arn:aws:lambda:us-east-1:111111111111:function:*" } }
        }]
      })]
    }
  }
  assert {
    condition     = [for s in jsondecode(aws_ecr_repository_policy.this[0].policy).Statement : s.Sid] == ["AccountReadAccess", "LambdaPull"]
    error_message = "Source statements must be added after the module's own."
  }
}

run "duplicate_sid_rejected" {
  command = plan
  variables {
    policy = {
      aws_account_read_access = ["222222222222"]
      source_policy_documents = [jsonencode({
        Version   = "2012-10-17"
        Statement = [{ Sid = "AccountReadAccess", Effect = "Allow", Principal = "*", Action = "ecr:ListImages" }]
      })]
    }
  }
  expect_failures = [aws_ecr_repository_policy.this]
}

run "account_id_validated" {
  command = plan
  variables { policy = { aws_account_read_access = ["12345"] } }
  expect_failures = [var.policy]
}

# Regression: an account ID given as an organization ID used to be accepted, and the
# statement silently matched nobody.
run "organization_id_validated" {
  command = plan
  variables { policy = { aws_organization_read_access = ["123456789012"] } }
  expect_failures = [var.policy]
}

run "source_policy_document_validated" {
  command = plan
  variables { policy = { source_policy_documents = ["{\"Version\": \"2012-10-17\"}"] } }
  expect_failures = [var.policy]
}

# The policy's count depends on the inputs only, so a policy document built from a
# resource created in the same run still plans.
run "same_run_policy_document" {
  command = plan
  module {
    source = "./tests/fixtures/same_run_policy"
  }
  assert {
    condition     = length(output.metadata.ecr_repository_policy[*]) == 1
    error_message = "The repository policy must be planned."
  }
}
