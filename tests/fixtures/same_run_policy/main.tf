# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

# A role created in the same run as the repository, whose ARN is unknown until apply.
resource "aws_iam_role" "puller" {
  name = "test-puller"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "codebuild.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

module "ecr" {
  source = "../../.."

  details    = { scope = "Test", purpose = "Same run", environment = "test" }
  image_name = "app"
  policy = {
    source_policy_documents = [jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid       = "RolePull"
        Effect    = "Allow"
        Principal = { AWS = aws_iam_role.puller.arn }
        Action    = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
      }]
    })]
  }
}

output "metadata" {
  value = module.ecr.metadata
}
