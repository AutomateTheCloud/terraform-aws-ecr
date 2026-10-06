# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Most of the module's options in one private repository: a namespace, lifecycle rules
# for release and test images, and read access for other accounts in your organization.

terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "read_access_account_ids" {
  description = "12-digit IDs of other AWS accounts that may pull images. Empty for none."
  type        = list(string)
  default     = []
}

variable "read_access_organization_ids" {
  description = "IDs of AWS Organizations (o-xxxxxxxxxx) whose accounts may pull images. Empty for none."
  type        = list(string)
  default     = []
}

module "ecr" {
  source = "../../"

  details = {
    scope            = "Example"
    purpose          = "Complete Repository"
    environment      = "Development"
    environment_abbr = "dev"
    additional_tags  = { CostCenter = "1234" }
  }

  namespace             = "example-team"
  image_name            = "example-app"
  enable_immutable_tags = true
  scan_on_push          = true
  force_delete          = false

  lifecycle_rules = [
    {
      priority    = 1
      description = "Delete untagged images after 7 days"
      selection   = { tag_status = "untagged", count_type = "sinceImagePushed", count_unit = "days", count_number = 7 }
    },
    {
      priority    = 10
      description = "Keep the newest 50 release images (v1.2.3)"
      selection   = { tag_status = "tagged", tag_prefix_list = ["v"], count_type = "imageCountMoreThan", count_number = 50 }
    },
    {
      priority    = 20
      description = "Delete release candidates after 30 days"
      selection   = { tag_status = "tagged", tag_pattern_list = ["*-rc*"], count_type = "sinceImagePushed", count_unit = "days", count_number = 30 }
    },
    {
      priority    = 100
      description = "Keep at most 500 images of any kind"
      selection   = { tag_status = "any", count_type = "imageCountMoreThan", count_number = 500 }
    },
  ]

  policy = {
    aws_account_read_access      = var.read_access_account_ids
    aws_organization_read_access = var.read_access_organization_ids
  }
}

output "metadata" {
  description = "Everything the module created"
  value       = module.ecr.metadata
}
