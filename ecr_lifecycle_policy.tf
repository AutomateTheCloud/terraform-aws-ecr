# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

resource "aws_ecr_lifecycle_policy" "this" {
  count      = length(var.lifecycle_rules) > 0 ? 1 : 0
  repository = aws_ecr_repository.this.name
  region     = var.region
  policy     = jsonencode({ rules = local.ecr_lifecycle_policy_rules })
}
