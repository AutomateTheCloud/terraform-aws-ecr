# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

resource "aws_ecr_repository" "this" {
  name   = local.repository_name
  region = var.region

  image_tag_mutability = var.enable_immutable_tags ? "IMMUTABLE" : "MUTABLE"
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  # Images are encrypted with AES-256 by default. encryption_configuration is not set:
  # changing it replaces the repository and deletes every image in it.

  tags = merge(
    local.tags,
    { "Name" = local.repository_name }
  )
}
