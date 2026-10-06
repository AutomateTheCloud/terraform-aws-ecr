# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# A repository that AWS Lambda functions in this account can pull container images
# from. The grant is limited to Lambda acting for functions in this account and
# Region, using policy.source_policy_documents.

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

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "lambda_pull" {
  statement {
    sid     = "LambdaPull"
    effect  = "Allow"
    actions = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    # Only for functions in this account and Region.
    condition {
      test     = "StringLike"
      variable = "aws:sourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:*"]
    }
  }
}

module "ecr" {
  source = "../../"

  details = {
    scope       = "Example"
    purpose     = "Lambda Images"
    environment = "Development"
  }

  image_name = "example-lambda"

  policy = {
    source_policy_documents = [data.aws_iam_policy_document.lambda_pull.json]
  }
}

output "repository_url" {
  description = "Use as the image URI of a Lambda function, followed by :<tag>"
  value       = module.ecr.metadata.ecr_repository.repository_url
}
