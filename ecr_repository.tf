resource "aws_ecr_repository" "this" {
  name = local.ecr.repository_name
  tags = local.tags

  image_tag_mutability = (var.enable_immutable_tags ? "IMMUTABLE" : "MUTABLE")
  image_scanning_configuration {
    scan_on_push = var.enable_scan
  }
  force_delete = var.force_delete
  provider     = aws.this
}
