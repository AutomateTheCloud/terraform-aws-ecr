# Copyright 2026 Automate the Cloud Inc.
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
  details    = { scope = "Test", purpose = "Lifecycle", environment = "test" }
  image_name = "app"
}

# Each rule becomes ECR's JSON form, with unset attributes left out.
run "lifecycle_policy_json" {
  command = plan
  variables {
    lifecycle_rules = [
      {
        priority    = 1
        description = "Delete untagged images after 7 days"
        selection   = { tag_status = "untagged", count_type = "sinceImagePushed", count_unit = "days", count_number = 7 }
      },
      {
        priority  = 2
        selection = { tag_status = "tagged", tag_pattern_list = ["*-rc*"], count_type = "imageCountMoreThan", count_number = 5 }
      },
      {
        priority  = 10
        selection = { tag_status = "any", count_type = "imageCountMoreThan", count_number = 100 }
      },
    ]
  }
  assert {
    condition = jsondecode(aws_ecr_lifecycle_policy.this[0].policy) == {
      rules = [
        {
          rulePriority = 1
          description  = "Delete untagged images after 7 days"
          selection    = { tagStatus = "untagged", countType = "sinceImagePushed", countUnit = "days", countNumber = 7 }
          action       = { type = "expire" }
        },
        {
          rulePriority = 2
          selection    = { tagStatus = "tagged", tagPatternList = ["*-rc*"], countType = "imageCountMoreThan", countNumber = 5 }
          action       = { type = "expire" }
        },
        {
          rulePriority = 10
          selection    = { tagStatus = "any", countType = "imageCountMoreThan", countNumber = 100 }
          action       = { type = "expire" }
        },
      ]
    }
    error_message = "Unexpected lifecycle policy."
  }
  assert {
    condition     = aws_ecr_lifecycle_policy.this[0].repository == "app"
    error_message = "The lifecycle policy must be on the repository."
  }
}

run "priority_unique" {
  command = plan
  variables {
    lifecycle_rules = [
      { priority = 1, selection = { tag_status = "untagged", count_type = "imageCountMoreThan", count_number = 1 } },
      { priority = 1, selection = { tag_status = "tagged", tag_prefix_list = ["v"], count_type = "imageCountMoreThan", count_number = 1 } },
    ]
  }
  expect_failures = [var.lifecycle_rules]
}

run "priority_whole_number" {
  command = plan
  variables {
    lifecycle_rules = [{ priority = 1.5, selection = { tag_status = "untagged", count_type = "imageCountMoreThan", count_number = 1 } }]
  }
  expect_failures = [var.lifecycle_rules]
}

run "tag_status_validated" {
  command = plan
  variables {
    lifecycle_rules = [{ priority = 1, selection = { tag_status = "Untagged", count_type = "imageCountMoreThan", count_number = 1 } }]
  }
  expect_failures = [var.lifecycle_rules]
}

run "tagged_needs_a_list" {
  command = plan
  variables {
    lifecycle_rules = [{ priority = 1, selection = { tag_status = "tagged", count_type = "imageCountMoreThan", count_number = 1 } }]
  }
  expect_failures = [var.lifecycle_rules]
}

run "tagged_not_both_lists" {
  command = plan
  variables {
    lifecycle_rules = [{ priority = 1, selection = { tag_status = "tagged", tag_prefix_list = ["v"], tag_pattern_list = ["v*"], count_type = "imageCountMoreThan", count_number = 1 } }]
  }
  expect_failures = [var.lifecycle_rules]
}

run "untagged_no_list" {
  command = plan
  variables {
    lifecycle_rules = [{ priority = 1, selection = { tag_status = "untagged", tag_prefix_list = ["v"], count_type = "imageCountMoreThan", count_number = 1 } }]
  }
  expect_failures = [var.lifecycle_rules]
}

run "count_unit_required_with_days" {
  command = plan
  variables {
    lifecycle_rules = [{ priority = 1, selection = { tag_status = "untagged", count_type = "sinceImagePushed", count_number = 14 } }]
  }
  expect_failures = [var.lifecycle_rules]
}

run "count_unit_not_allowed_with_count" {
  command = plan
  variables {
    lifecycle_rules = [{ priority = 1, selection = { tag_status = "untagged", count_type = "imageCountMoreThan", count_unit = "days", count_number = 1 } }]
  }
  expect_failures = [var.lifecycle_rules]
}

run "count_number_validated" {
  command = plan
  variables {
    lifecycle_rules = [{ priority = 1, selection = { tag_status = "untagged", count_type = "imageCountMoreThan", count_number = 0 } }]
  }
  expect_failures = [var.lifecycle_rules]
}

run "any_rule_last" {
  command = plan
  variables {
    lifecycle_rules = [
      { priority = 1, selection = { tag_status = "any", count_type = "imageCountMoreThan", count_number = 100 } },
      { priority = 2, selection = { tag_status = "untagged", count_type = "imageCountMoreThan", count_number = 1 } },
    ]
  }
  expect_failures = [var.lifecycle_rules]
}
