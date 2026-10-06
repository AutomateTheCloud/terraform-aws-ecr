# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# A private repository with immutable tags and scan on push, and a lifecycle policy
# that deletes untagged images. This is a sensible starting point for most repositories.

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

module "ecr" {
  source = "../../"

  details = {
    scope       = "Example"
    purpose     = "Basic Repository"
    environment = "Development"
  }

  image_name = "example-app"

  lifecycle_rules = [
    {
      priority    = 1
      description = "Delete untagged images after 14 days"
      selection = {
        tag_status   = "untagged"
        count_type   = "sinceImagePushed"
        count_unit   = "days"
        count_number = 14
      }
    }
  ]
}

output "repository" {
  description = "Name, ARN and URL of the repository"
  value = {
    name = module.ecr.metadata.ecr_repository.name
    arn  = module.ecr.metadata.ecr_repository.arn
    url  = module.ecr.metadata.ecr_repository.repository_url
  }
}
