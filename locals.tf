# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

locals {
  repository_name = var.namespace == "" ? var.image_name : "${var.namespace}/${var.image_name}"

  # Pulling and listing images. ecr:GetAuthorizationToken is not here: it applies to the
  # whole registry, not one repository, so it has no effect in a repository policy.
  # Whoever pulls needs it in their own IAM policy.
  ecr_read_actions = [
    "ecr:BatchCheckLayerAvailability",
    "ecr:BatchGetImage",
    "ecr:DescribeImageScanFindings",
    "ecr:DescribeImages",
    "ecr:DescribeRepositories",
    "ecr:GetDownloadUrlForLayer",
    "ecr:ListImages",
  ]

  # Every statement the policy can contain, each switched on by an input. A policy is
  # created only when at least one statement is switched on.
  ecr_repository_policy_statements = concat(
    # AWS Account Read Access (share)
    [for s in [{
      Sid       = "AccountReadAccess"
      Effect    = "Allow"
      Principal = { AWS = [for account in var.policy.aws_account_read_access : "arn:${local.aws.partition}:iam::${account}:root"] }
      Action    = local.ecr_read_actions
    }] : s if length(var.policy.aws_account_read_access) > 0],

    # AWS Organization Read Access (share)
    [for s in [{
      Sid       = "OrganizationReadAccess"
      Effect    = "Allow"
      Principal = "*"
      Action    = local.ecr_read_actions
      Condition = { StringEquals = { "aws:PrincipalOrgID" = var.policy.aws_organization_read_access } }
    }] : s if length(var.policy.aws_organization_read_access) > 0],

    # Statements from the caller's own policy documents
    flatten([for doc in var.policy.source_policy_documents : jsondecode(doc).Statement]),
  )

  # Decided from the inputs alone, so the count is known at plan time.
  create_ecr_repository_policy = anytrue([
    length(var.policy.aws_account_read_access) > 0,
    length(var.policy.aws_organization_read_access) > 0,
    length(var.policy.source_policy_documents) > 0,
  ])

  # Lifecycle rules in the JSON form ECR expects, leaving out unset attributes.
  ecr_lifecycle_policy_rules = [for rule in var.lifecycle_rules : {
    for k, v in {
      rulePriority = rule.priority
      description  = rule.description
      selection = {
        for k, v in {
          tagStatus      = rule.selection.tag_status
          tagPrefixList  = rule.selection.tag_prefix_list
          tagPatternList = rule.selection.tag_pattern_list
          countType      = rule.selection.count_type
          countUnit      = rule.selection.count_unit
          countNumber    = rule.selection.count_number
        } : k => v if v != null
      }
      action = { type = "expire" }
    } : k => v if v != null
  }]
}
