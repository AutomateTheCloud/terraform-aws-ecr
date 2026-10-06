# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

resource "aws_ecr_repository_policy" "this" {
  count      = local.create_ecr_repository_policy ? 1 : 0
  repository = aws_ecr_repository.this.name
  region     = var.region
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = local.ecr_repository_policy_statements
  })

  lifecycle {
    precondition {
      condition     = length(local.ecr_repository_policy_sids) == length(distinct(local.ecr_repository_policy_sids))
      error_message = "Repository policy statement IDs (Sid) must be unique. Check policy.source_policy_documents against the module's own statements: ${join(", ", local.ecr_repository_policy_sids)}."
    }
  }
}

locals {
  ecr_repository_policy_sids = compact([for s in local.ecr_repository_policy_statements : try(s.Sid, "")])
}
