terraform {
  required_version = "~> 1.11.0"
}

##-----------------------------------------------------------------------------
# Providers
provider "aws" {
  alias  = "example"
  region = "us-east-1"
}

##-----------------------------------------------------------------------------
# Module: ECR
module "ecr" {
  source    = "../"
  providers = { aws.this = aws.example }

  details = {
    scope       = "Demo"
    purpose     = "ECR"
    environment = "prd"
    additional_tags = {
      "Project"   = "Project Name"
      "ProjectID" = "123456789"
      "Contact"   = "David Singer - david.singer@example.com"
    }
  }

  namespace             = "organization"
  image_name            = "demo-image"
  enable_immutable_tags = true
  enable_scan           = true
  lifecycle_rules = [
    {
      rulePriority = 1
      description  = "Remove untagged images"
      selection = {
        tagStatus   = "untagged"
        countType   = "imageCountMoreThan"
        countNumber = 1
      },
      action = {
        type = "expire"
      }
    },
    {
      rulePriority = 2,
      description  = "Rotate images when more than 300 stored"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 300
      },
      action = {
        type = "expire"
      }
    }
  ]
  accounts_read_access = [
    "012345678901"
  ]
  organization_read_access = [
    "o-123456"
  ]
}

##-----------------------------------------------------------------------------
# Outputs
output "metadata" {
  description = "Metadata"
  value       = module.ecr.metadata
}
